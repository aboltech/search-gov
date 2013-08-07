class TrendingUrl
  ONE_HOUR_IN_SECONDS = 3600
  DEFAULT_HISTORICAL_HOURS = 24
  TOP_COUNT = 100

  attr_accessor :affiliate_name, :url

  cattr_reader :redis
  @@redis = Redis.new(:host => REDIS_HOST, :port => REDIS_PORT)

  def self.all
    sorted_trending_affiliate_keys = @@redis.keys("TrendingUrls:*").sort
    trending_urls = []
    sorted_trending_affiliate_keys.each do |key|
      aff_name = key.split(':').last
      @@redis.smembers(key).sort.each do |trending_url|
        trending_urls << new(aff_name, trending_url)
      end
    end
    trending_urls
  end

  def initialize(affiliate_name, url)
    self.affiliate_name, self.url = affiliate_name, url
  end

  def current_rank
    get_rank(hour_format(0))
  end

  def average_rank
    ranks = historical_ranks(DEFAULT_HISTORICAL_HOURS)
    return nil if ranks.empty?
    sum_total = ranks.inject(0) { |x, sum| sum += x }
    sum_total / ranks.size
  end

  def historical_ranks(count = DEFAULT_HISTORICAL_HOURS)
    @historical_ranks ||= (1..count).map do |hour_offset|
      get_rank(hour_format(hour_offset))
    end.compact
  end

  def hour_format(hours_back)
    (Time.now.utc - (hours_back * ONE_HOUR_IN_SECONDS)).strftime("%Y%m%d%H")
  end

  def get_rank(hour)
    key = ['UrlCounts', hour, self.affiliate_name].join(":")
    top_urls = @@redis.zrevrange(key, 0, TOP_COUNT - 1)
    top_urls.index(self.url)
  end

end
