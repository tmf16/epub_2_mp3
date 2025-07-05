require 'fileutils'
require 'uri'
require 'net/http'
require 'json'
require 'openssl'
require 'dotenv/load'

class TextToMp3Converter
  MAX_CHARS = 4096
  OPENAI_API_URL = "https://api.openai.com/v1/audio/speech"
  VOICE_INSTRUCTIONS = <<~EOS.strip
    声： 温かく、共感的で、プロフェッショナルであり、顧客の問題が理解され、解決されることを安心させる。
    句読点： 自然な間があり、明瞭で安定した落ち着いた流れを可能にする。
    デリバリー： 穏やかで忍耐強く、聞き手を安心させるサポートと理解のある口調。
    トーン：共感的で解決策を重視し、理解と積極的な支援の両方を強調する。
  EOS

  def initialize(input_path, output_dir: "files/mp3", tmp_dir_base: "files/tmp")
    @input_path = input_path
    @basename = File.basename(input_path, ".*")
    @output_dir = output_dir
    @tmp_dir = File.join(tmp_dir_base, @basename)
    @api_key = ENV['OPENAI_API_KEY']
    @uri = URI(OPENAI_API_URL)
    FileUtils.mkdir_p(@tmp_dir)
    FileUtils.mkdir_p(@output_dir)
  end

  def run
    text = File.read(@input_path)
    chunks = split_text(text)
    
    mp3_files = []
    chunks.each_with_index do |chunk, idx|
      mp3_file = process_chunk(chunk, idx)
      mp3_files << mp3_file if mp3_file
    end

    concatenate_mp3s(mp3_files)
  end

  def split_text(text)
    paragraphs = text.split(/\n{2,}/).map(&:strip).reject(&:empty?)
    chunks = []
    current_chunk = ""

    paragraphs.each do |para|
      if para.length > MAX_CHARS
        para.chars.each_slice(MAX_CHARS) do |sub_para_chars|
          sub_para = sub_para_chars.join
          if (current_chunk + sub_para).length > MAX_CHARS && !current_chunk.empty?
            chunks << current_chunk
            current_chunk = sub_para
          else
            current_chunk += sub_para
          end
        end
      else
        if (current_chunk + "\n\n" + para).length > MAX_CHARS && !current_chunk.empty?
          chunks << current_chunk
          current_chunk = para
        else
          current_chunk += "\n\n" unless current_chunk.empty?
          current_chunk += para
        end
      end
    end
    chunks << current_chunk unless current_chunk.empty?
    chunks
  end

  def process_chunk(chunk, index)
    filename_txt = format("%03d.txt", index + 1)
    filepath_txt = File.join(@tmp_dir, filename_txt)
    File.write(filepath_txt, chunk)
    puts "✅ Wrote: #{filepath_txt} (#{chunk.length} chars)"

    filename_mp3 = filename_txt.sub(/\.txt$/, ".mp3")
    filepath_mp3 = File.join(@tmp_dir, filename_mp3)

    return filepath_mp3 if create_mp3(chunk, filepath_mp3, filename_txt)
    nil
  end

  def create_mp3(chunk, filepath_mp3, origin_filename)
    req = Net::HTTP::Post.new(@uri)
    req["Authorization"] = "Bearer #{@api_key}"
    req["Content-Type"] = "application/json"
    req["OpenAI-Beta"] = "assistants=v2"
    req.body = {
      model: "tts-1",
      input: chunk,
      voice: "echo",
      speed: 1.0,
      response_format: "mp3",
      instructions: VOICE_INSTRUCTIONS
    }.to_json

    begin
      Net::HTTP.start(@uri.host, @uri.port, use_ssl: true) do |http|
        http.request(req) do |res|
          if res.is_a?(Net::HTTPSuccess)
            File.open(filepath_mp3, "wb") do |f|
              res.read_body { |segment| f.write(segment) }
            end
            puts "🎧 MP3 created: #{filepath_mp3}"
            return true
          else
            warn "⚠️ Failed MP3 for #{origin_filename} - #{res.code}: #{res.body}"
            return false
          end
        end
      end
    rescue => e
      warn "🚨 HTTP Request failed for #{origin_filename}: #{e.message}"
      return false
    end
  end

  def concatenate_mp3s(mp3_files)
    return if mp3_files.empty?

    output_path = File.join(@output_dir, "#{@basename}.mp3")
    concat_txt = File.join(@tmp_dir, "concat.txt")

    File.open(concat_txt, "w") do |f|
      mp3_files.each { |mp3| f.puts "file '#{File.expand_path(mp3)}'" }
    end

    puts "🔄 Concatenating MP3 files..."
    ffmpeg_cmd = [
      "ffmpeg", "-y",
      "-f", "concat", "-safe", "0",
      "-i", concat_txt,
      "-c", "copy",
      output_path
    ]

    if system(*ffmpeg_cmd)
      puts "🎉 Final MP3 created: #{output_path}"
    else
      warn "❌ ffmpeg failed"
    end
  end
end

if __FILE__ == $0
  if ARGV.empty?
    puts "Usage: ruby #{$0} <input_text_file> [output_directory]"
    exit 1
  end

  input_path = ARGV[0]
  unless File.exist?(input_path)
    puts "Error: File not found - #{input_path}"
    exit 1
  end

  output_dir = ARGV[1] || "files/mp3"
  converter = TextToMp3Converter.new(input_path, output_dir: output_dir)
  converter.run
end
