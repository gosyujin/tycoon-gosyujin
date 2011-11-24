# encoding: utf-8
require 'rubygems'
require 'sinatra'
require 'openssl'
require 'uri'
require 'net/http'
require 'nkf'
require 'time'
require './simplejsonparser'

class Twitter
  def initialize()
    @get = 'http://api.twitter.com/1/statuses/home_timeline.json'
    @core = {
      "consumer_key" => ENV["CONSUMER_KEY"], 
      "consumer_secret" => ENV["CONSUMER_SECRET"], 
      "oauth_token" => ENV["OAUTH_TOKEN"], 
      "oauth_token_secret" => ENV["OAUTH_TOKEN_SECRET"]
    }
puts @core
    consumer_key = @core["consumer_key"]
    consumer_secret = @core["consumer_secret"]
    oauth_token = @core["oauth_token"]
    oauth_token_secret = @core["oauth_token_secret"]
	
    @oauth_header = {
      # Consumer Key
      "oauth_consumer_key" => consumer_key,
      "oauth_nonce" => "AAAAAAAA",
      "oauth_signature_method" => "HMAC-SHA1",
      "oauth_timestamp" => Time.now.to_i.to_s,
      "oauth_version" => "1.0",
	  "oauth_token" => oauth_token 
    }

    @oauth_header["oauth_signature"] = signature("GET", 
	  consumer_secret, oauth_token_secret, @get, @oauth_header)
  end

  # signature作成
  def signature(method, consumer_secret, oauth_token_secret, url, oauth_header)
    signature_key = consumer_secret + "&"
    if !oauth_token_secret.nil? then
      signature_key += oauth_token_secret
    end
    param = sort_and_concat(oauth_header)
    
	# httpメソッドとURLとパラメータを&で連結する
    value = method + "&" + escape(url) + "&" + escape(param)
    sha1 = OpenSSL::HMAC.digest(OpenSSL::Digest::SHA1.new, signature_key, value)
    base64 = [sha1].pack('m').gsub(/\n/, '')
    return base64
  end
  
  # 文字列のエスケープ(: / = %をエスケープする。. _ -はそのまま)
  def escape(value)
    URI.escape(value, Regexp.new("[^a-zA-Z0-9._-]"))
  end
  
  # oauth_headerの情報をアルファベット順に並べ替え & で結合
  def sort_and_concat(oauth_header)
    oauth_header_array = oauth_header.sort
    param = ""
    oauth_header_array.each do |params|
      for i in 1..params.length
        param += params[i-1]
          if i % params.length == 0
            param += "&"
          else
            param += "="
          end
        end
      end
    param = param.slice(0, param.length-1)
end

  def get()
    uri = URI.parse(@get)
    proxy_class = Net::HTTP::Proxy(ENV['PROXY'], 8080)
    http = proxy_class.new(uri.host)
    http.start do |http|
      # oauth_headerのパラメータをソートして連結
      param = sort_and_concat(@oauth_header)
      res = http.get(uri.path + "?#{param}")
      if res.code == "200" then
        return JsonParser.new.parse(res.body)
      else
        return res.code
      end
    end
  end
end

get '/' do
  tw = Twitter.new()
  json = tw.get()
  if json == "401" then 
    puts "REDIRECT"
    redirect "/"
  end
  
  tag = "<style type='text/css'>" + 
        ".head {}" + 
        ".time {}" + 
        ".tweet {}</style>" + 
        "<h1>Hello Tycoon-Timeline powerd by Heroku!!</h1>" + 
        "<a href=''>Reload</a>" + 
        "<dl>"
  json.each do |tweet|
    tag += "<dt class='head'>#{tweet["user"]["screen_name"]} (#{tweet["user"]["name"]}) " + 
	             "<span class='time'>#{Time.parse(tweet["created_at"]).strftime("%Y/%m/%d %X")}</span></dt>" + 
	            "<dd class='tweet'>#{tweet["text"]}</dd>"
  end
  tag += "</dl>"
  return tag
end
