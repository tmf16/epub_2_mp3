require 'minitest/autorun'
require_relative '../epub_2_text'

class TestEpubToTextConverter < Minitest::Test
  def setup
    @epub_path = File.expand_path("test/fixtures/gakumon_no_susume.epub", Dir.pwd)
    @output_dir = "test/tmp_output"
    FileUtils.rm_rf(@output_dir)
    FileUtils.mkdir_p(@output_dir)

    @converter = EpubToTextConverter.new(@epub_path, @output_dir)
  end

  def teardown
    FileUtils.rm_rf(@output_dir)
  end

  def test_clean_and_format_lines_default_behavior
    lines = [
      "  leading and trailing spaces  ",
      "",
      "		",
      "Line with content."
    ]
    expected = [
      "leading and trailing spaces",
      "Line with content."
    ]
    assert_equal expected, @converter.send(:clean_and_format_lines, lines)
  end

  def test_determine_filename_with_h_tag
    doc = Nokogiri::HTML("<html><body><h1>Test Title</h1></body></html>")
    first_line_text = "First line of text"
    filename = @converter.send(:determine_filename, doc, first_line_text)
    assert_equal "000_Test_Title.txt", filename
  end

  def test_determine_filename_without_h_tag
    doc = Nokogiri::HTML("<html><body><p>No H Tag</p></body></html>")
    first_line_text = "First line of text"
    filename = @converter.send(:determine_filename, doc, first_line_text)
    assert_equal "000_First_line_of_text.txt", filename
  end

  def test_convert_creates_correct_number_of_files
    @converter.convert
    assert_equal 19, Dir.glob(File.join(@output_dir, "*.txt")).count
  end

  def test_convert_generates_expected_content
    @converter.convert
    first_file_path = File.join(@output_dir, "000_学問のすすめ.txt")
    assert File.exist?(first_file_path)
    content = File.read(first_file_path)
    assert_includes content, "学問のすすめ"
  end
end
