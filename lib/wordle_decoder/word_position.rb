# frozen_string_literal: true

class WordleDecoder
  class WordPosition
    def initialize(hint_line, answer_chars)
      @answer_chars = answer_chars
      @letter_positions = initialize_letter_positions(hint_line, answer_chars)
    end

    attr_reader :answer_chars,
                :letter_positions

    def words
      @words ||= initialize_words
    end

    BASE_INCONFIDENCE = 0.05

    def confidence_score
      score = (100 * (1.0 / words.count.to_f))
      (score - (score * BASE_INCONFIDENCE)).round
    end

    def green_letter_positions
      @green_letter_positions ||= select_letter_positions_by_hint("g")
    end

    def yellow_letter_positions
      @yellow_letter_positions ||= select_letter_positions_by_hint("y")
    end

    def black_letter_positions
      @black_letter_positions ||= select_letter_positions_by_hint("b")
    end

    private

    def initialize_words
      potential_words = intersect_potential_and_impossible_words
      potential_words.map! { |str| Word.new(str, self) }
      potential_words.select!(&:possible?)
      potential_words
    end

    def intersect_potential_and_impossible_words
      WordSearch::COMMONALITY_OPTIONS.each do |commonality|
        words = compute_words_from_hints(commonality)
        case words.count
        when 1
          return words
        when 0
          next
        end

        words = remove_impossible_words(words, commonality)
        return words unless words.empty?
      end
    end

    def compute_words_from_hints(commonality)
      words = nil
      [green_letter_positions, yellow_letter_positions].each do |letters|
        words = filter_by_words(words, letters, commonality) if letters
      end
      words
    end

    def filter_by_words(words, letters, commonality)
      letters.each do |letter|
        if words
          words &= letter.potential_words(commonality)
        else
          words = letter.potential_words(commonality)
        end
      end
      words
    end

    def remove_impossible_words(words, commonality)
      black_letter_positions&.each do |letter|
        words -= letter.impossible_words(commonality)
      end
      words
    end

    def select_letter_positions_by_hint(hint_char)
      @letter_positions.select { |lg| lg.hint_char == hint_char }
    end

    def initialize_letter_positions(hint_line, answer_chars)
      hint_line.each_char.map.with_index do |hint_char, index|
        LetterPosition.new(hint_char, answer_chars, index)
      end
    end

    class LetterPosition
      EMOJI_HINT_CHARS = { "⬛" => "b",
                           "🟨" => "y",
                           "🟩" => "g" }.freeze

      def initialize(hint_char, answer_chars, index)
        @hint_char = EMOJI_HINT_CHARS[hint_char] || hint_char
        @answer_chars = answer_chars
        @index = index
        @answer_char = @answer_chars[index]
      end

      attr_reader :hint_char,
                  :answer_char,
                  :index

      def potential_words(commonality)
        case hint_char
        when "g"
          WordSearch.char_at_index(@answer_char, @index, commonality)
        when "y"
          chars = @answer_chars - [@answer_char]
          WordSearch.chars_at_index(chars, @index, commonality)
        end
      end

      def impossible_words(commonality)
        WordSearch.chars_at_index(@answer_chars, @index, commonality)
      end
    end
  end
end
