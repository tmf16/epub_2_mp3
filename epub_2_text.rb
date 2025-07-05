require 'epub/parser'
require 'nokogiri'
require 'fileutils'

class EpubToTextConverter

  def initialize(epub_path, output_dir)
    @epub_path = epub_path
    @output_dir = output_dir
    @serial_number = 0
    FileUtils.mkdir_p(@output_dir)
  end

  def convert
    FileUtils.rm_rf(Dir.glob(File.join(@output_dir, '*')))

    book = EPUB::Parser.parse(@epub_path)

    book.spine.items.each do |item|
      begin
        content = item.read
        doc = Nokogiri::HTML(content)
        raw_text = doc.text

        lines = raw_text.lines.map(&:strip).reject(&:empty?)
        cleaned_lines = clean_and_format_lines(lines)

        next if cleaned_lines.empty?

        filename = determine_filename(doc, cleaned_lines.first)
        write_text_file(filename, cleaned_lines.join("\n"))

        @serial_number += 1
      rescue => e
        warn "⚠️ Error processing #{item.href}: #{e.class} - #{e.message}"
      end
    end
  end

  private

  def clean_and_format_lines(lines)
    # このメソッドは、EPUBから抽出したテキスト行を整形するためのものです。
    # 書籍によって不要な情報やフォーマットが異なるため、
    # 必要に応じてこのメソッドをカスタマイズしてください。
    #
    # 例:
    # lines.map do |line|
    #   line.gsub(/不要な文字列/, '').strip
    # end.reject(&:empty?)

    lines.map(&:strip).reject(&:empty?)
  end

  def determine_filename(doc, first_line_text)
    title_for_filename = nil
    (1..6).each do |i|
      h_tag = doc.at_css("h#{i}")
      if h_tag && !h_tag.text.strip.empty?
        title_for_filename = h_tag.text.strip
        break
      end
    end

    unless title_for_filename
      title_for_filename = first_line_text.to_s.strip
    end

    title_for_filename = title_for_filename.gsub(/\s+/, '_')
    title_for_filename = title_for_filename.gsub(/[^a-zA-Z0-9\p{Hiragana}\p{Katakana}\p{Han}_.]/, '').strip

    format('%03d_%s.txt', @serial_number, title_for_filename)
  end

  def write_text_file(filename, text_content)
    filepath = File.join(@output_dir, filename)
    File.write(filepath, text_content)
    puts "✅ Wrote: #{filepath}"
  end
end

if __FILE__ == $0
  if ARGV.empty?
    puts "Usage: ruby #{$PROGRAM_NAME} <epub_file_path> [output_directory]"
    exit
  end
  epub_path = ARGV[0]

  unless File.exist?(epub_path)
    puts "Error: File not found - #{epub_path}"
    exit
  end

  output_dir = ARGV[1] || 'files/text/'
  converter = EpubToTextConverter.new(epub_path, output_dir)
  converter.convert
end