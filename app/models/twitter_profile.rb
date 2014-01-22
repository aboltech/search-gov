class TwitterProfile < ActiveRecord::Base
  has_many :tweets, :primary_key => :twitter_id, :dependent => :destroy
  has_many :affiliate_twitter_settings, dependent: :destroy
  has_many :affiliates, through: :affiliate_twitter_settings
  has_and_belongs_to_many :twitter_lists
  validates_presence_of :name, :profile_image_url, :screen_name, :twitter_id
  validates_uniqueness_of :twitter_id
  before_validation :normalize_screen_name, if: :screen_name?
  scope :active, joins(:affiliate_twitter_settings).uniq
  scope :show_lists_enabled, active.where('affiliate_twitter_settings.show_lists = 1').order('twitter_profiles.updated_at asc, twitter_profiles.id asc').uniq

  def link_to_profile
    "http://twitter.com/#{screen_name}"
  end

  def self.affiliate_twitter_ids
    active.select(:twitter_id).uniq.map(&:twitter_id)
  end

  private

  def normalize_screen_name
    self.screen_name = screen_name.gsub(/[@ ]/,'')
  end
end
