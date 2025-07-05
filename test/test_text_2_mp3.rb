require 'minitest/autorun'
require 'fileutils'
require_relative '../text_2_mp3'

class TestTextToMp3Converter < Minitest::Test
  def setup
    @dummy_input_path = 'test/fixtures/dummy.txt'
    @test_tmp_dir = 'test/tmp'
    FileUtils.rm_rf(@test_tmp_dir)
    FileUtils.mkdir_p(@test_tmp_dir)

    @converter = TextToMp3Converter.new(
      @dummy_input_path,
      output_dir: File.join(@test_tmp_dir, 'mp3'),
      tmp_dir_base: @test_tmp_dir
    )
  end

  def teardown
    FileUtils.rm_rf(@test_tmp_dir)
  end

  def test_split_text_with_short_text
    text = "This is a short text."
    chunks = @converter.split_text(text)
    assert_equal 1, chunks.size
    assert_equal text, chunks.first
  end

  def test_split_text_with_long_text_exceeding_max_chars
    long_word = "a" * (TextToMp3Converter::MAX_CHARS + 10)
    chunks = @converter.split_text(long_word)
    assert_equal 2, chunks.size
    assert_equal TextToMp3Converter::MAX_CHARS, chunks.first.length
    assert_equal 10, chunks.last.length
  end

  def test_split_text_with_multiple_paragraphs
    para1 = "First paragraph."
    para2 = "Second paragraph."
    text = [para1, para2].join("\n\n")
    chunks = @converter.split_text(text)
    assert_equal 1, chunks.size
    assert_equal text, chunks.first
  end

  def test_split_text_based_on_paragraph_and_max_chars
    para_size = (TextToMp3Converter::MAX_CHARS / 2) + 10
    para = "a" * para_size
    text = [para, para, para].join("\n\n")
    chunks = @converter.split_text(text)
    assert_equal 3, chunks.size
    assert_equal para, chunks[0]
    assert_equal para, chunks[1]
    assert_equal para, chunks[2]
  end

  def test_split_text_with_empty_string
    text = ""
    chunks = @converter.split_text(text)
    assert chunks.empty?
  end

  def test_split_text_with_only_newlines
    text = "\n\n\n"
    chunks = @converter.split_text(text)
    assert chunks.empty?
  end

  def test_create_mp3_success
    chunk = "test content"
    filepath_mp3 = File.join(@test_tmp_dir, 'test.mp3')
    origin_filename = '001.txt'
    mock_mp3_data = "dummy_mp3_binary_data"

    mock_res = Object.new
    def mock_res.is_a?(klass); klass == Net::HTTPSuccess; end
    def mock_res.read_body(&block); block.call("dummy_mp3_binary_data"); end

    mock_http = Object.new
    mock_http.define_singleton_method(:request) do |req, &block|
      block.call(mock_res)
    end

    Net::HTTP.stub :start, ->(host, port, **opts, &block) { block.call(mock_http) } do
      result = @converter.create_mp3(chunk, filepath_mp3, origin_filename)

      assert result, "成功時にはtrueが返されるはず"
      assert File.exist?(filepath_mp3), "MP3ファイルが作成されているはず"
      assert_equal mock_mp3_data, File.read(filepath_mp3), "ファイルの内容が正しいはず"
    end
  end

  def test_create_mp3_failure
    chunk = "test content"
    filepath_mp3 = File.join(@test_tmp_dir, 'test.mp3')
    origin_filename = '001.txt'

    mock_res = Object.new
    def mock_res.is_a?(klass); false; end
    def mock_res.code; '500'; end
    def mock_res.body; 'Internal Server Error'; end

    mock_http = Object.new
    mock_http.define_singleton_method(:request) do |req, &block|
      block.call(mock_res)
    end

    Net::HTTP.stub :start, ->(host, port, **opts, &block) { block.call(mock_http) } do
      _stdout, stderr = capture_io do
        result = @converter.create_mp3(chunk, filepath_mp3, origin_filename)
        assert !result, "失敗時にはfalseが返されるはず"
        assert !File.exist?(filepath_mp3), "MP3ファイルが作成されないはず"
      end
      assert_match /⚠️ Failed MP3 for #{origin_filename}/, stderr
    end
  end

  def test_concatenate_mp3s_success
    mp3_files = ['001.mp3', '002.mp3'].map do |f|
      path = File.join(@converter.instance_variable_get(:@tmp_dir), f)
      FileUtils.touch(path)
      path
    end

    @converter.stub :system, true do
      stdout, _stderr = capture_io do
        @converter.concatenate_mp3s(mp3_files)
      end
      assert_match /🎉 Final MP3 created/, stdout
    end

    concat_txt_path = File.join(@converter.instance_variable_get(:@tmp_dir), 'concat.txt')
    assert File.exist?(concat_txt_path)
    lines = File.readlines(concat_txt_path).map(&:strip)
    assert_equal "file '#{File.expand_path(mp3_files[0])}'", lines[0]
    assert_equal "file '#{File.expand_path(mp3_files[1])}'", lines[1]
  end

  def test_concatenate_mp3s_failure
    mp3_files = ['001.mp3'].map do |f|
      path = File.join(@converter.instance_variable_get(:@tmp_dir), f)
      FileUtils.touch(path)
      path
    end

    @converter.stub :system, false do
      _stdout, stderr = capture_io do
        @converter.concatenate_mp3s(mp3_files)
      end
      assert_match /❌ ffmpeg failed/, stderr
    end
  end

  def test_concatenate_mp3s_with_no_files
    mock = Minitest::Mock.new
    mock.expect :system, nil, [Object]

    @converter.stub :system, ->(*args) { mock.system(*args) } do
      @converter.concatenate_mp3s([])
    end
  end
end