class SaytSuggestion < ActiveRecord::Base
  validates_presence_of :phrase
  validates_uniqueness_of :phrase
  validates_length_of :phrase, :within=> (3..50)
  validates_format_of :phrase, :with=> /^[\w\s-]+$/i

  def self.populate_for(day)
    filtered_daily_query_stats = SaytFilter.filter(DailyQueryStat.find_all_by_day(day), "query")
    filtered_daily_query_stats.each do |dqs|
      create(:phrase => dqs.query)
    end unless filtered_daily_query_stats.empty?
  end
end
