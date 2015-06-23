require 'digest'
require 'sass/css'

class Affiliate < ActiveRecord::Base
  include ActiveRecordExtension
  extend AttributeSquisher
  include XmlProcessor
  CLOUD_FILES_CONTAINER = 'affiliate images'
  MAXIMUM_IMAGE_SIZE_IN_KB = 512
  MAXIMUM_MOBILE_IMAGE_SIZE_IN_KB = 64.freeze
  MAXIMUM_HEADER_TAGLINE_LOGO_IMAGE_SIZE_IN_KB = 16.freeze
  VALID_IMAGE_CONTENT_TYPES = %w(image/gif image/jpeg image/pjpeg image/png image/x-png).freeze
  INVALID_CONTENT_TYPE_MESSAGE = 'must be GIF, JPG, or PNG'.freeze
  INVALID_IMAGE_SIZE_MESSAGE = "must be under #{MAXIMUM_IMAGE_SIZE_IN_KB} KB".freeze
  INVALID_MOBILE_IMAGE_SIZE_MESSAGE = "must be under #{MAXIMUM_MOBILE_IMAGE_SIZE_IN_KB} KB".freeze
  INVALID_HEADER_TAGLINE_LOGO_IMAGE_SIZE_MESSAGE = "must be under #{MAXIMUM_HEADER_TAGLINE_LOGO_IMAGE_SIZE_IN_KB} KB".freeze
  MAX_NAME_LENGTH = 33.freeze

  with_options dependent: :destroy do |assoc|
    assoc.has_many :memberships
    assoc.has_many :features, :through => :affiliate_feature_addition
    assoc.has_many :boosted_contents
    assoc.has_many :sayt_suggestions
    assoc.has_many :superfresh_urls
    assoc.has_many :featured_collections
    assoc.has_many :indexed_documents
    assoc.has_many :rss_feeds, as: :owner, order: 'rss_feeds.name ASC, rss_feeds.id ASC'
    assoc.has_many :excluded_urls
    assoc.has_many :site_domains, :order => 'domain ASC'
    assoc.has_many :excluded_domains, :order => 'domain ASC'
    assoc.has_many :affiliate_feature_addition
    assoc.has_many :connections, :order => 'connections.position ASC'
    assoc.has_many :connected_connections, :foreign_key => :connected_affiliate_id, :source => :connections, :class_name => 'Connection'
    assoc.has_many :document_collections, :order => 'document_collections.name ASC, document_collections.id ASC'
    assoc.has_many :flickr_profiles, order: 'flickr_profiles.url ASC'
    assoc.has_many :facebook_profiles
    assoc.has_one :image_search_label
    assoc.has_many :navigations, :order => 'navigations.position ASC, navigations.id ASC'
    assoc.has_one :site_feed_url
    assoc.has_many :affiliate_twitter_settings
    assoc.has_many :i14y_memberships
    assoc.has_many :routed_queries
  end

  has_many :users, order: 'contact_name', through: :memberships
  has_many :default_users, class_name: 'User', foreign_key: 'default_affiliate_id', dependent: :nullify
  has_many :rss_feed_urls, through: :rss_feeds, uniq: true
  has_many :url_prefixes, :through => :document_collections
  has_many :twitter_profiles, through: :affiliate_twitter_settings, order: 'twitter_profiles.screen_name ASC'
  has_and_belongs_to_many :instagram_profiles, order: 'instagram_profiles.username ASC'
  has_and_belongs_to_many :youtube_profiles, order: 'youtube_profiles.title ASC'
  has_many :i14y_drawers, order: 'handle', through: :i14y_memberships
  belongs_to :agency

  belongs_to :status
  belongs_to :language, foreign_key: :locale, primary_key: :code

  
  has_attached_file :page_background_image,
                    :styles => { :large => "300x150>" },
                    :storage => :cloud_files,
                    :cloudfiles_credentials => "#{Rails.root}/config/rackspace_cloudfiles.yml",
                    :container => CLOUD_FILES_CONTAINER,
                    :path => "#{Rails.env}/:id/page_background_image/:updated_at/:style/:basename.:extension",
                    :ssl => true
  has_attached_file :header_image,
                    :styles => { :large => "300x150>" },
                    :storage => :cloud_files,
                    :cloudfiles_credentials => "#{Rails.root}/config/rackspace_cloudfiles.yml",
                    :container => CLOUD_FILES_CONTAINER,
                    :path => "#{Rails.env}/:id/managed_header_image/:updated_at/:style/:basename.:extension",
                    :ssl => true
  has_attached_file :mobile_logo,
                    :styles => { :large => "300x150>" },
                    :storage => :cloud_files,
                    :cloudfiles_credentials => "#{Rails.root}/config/rackspace_cloudfiles.yml",
                    :container => CLOUD_FILES_CONTAINER,
                    :path => "#{Rails.env}/:id/mobile_logo/:updated_at/:style/:basename.:extension",
                    :ssl => true  
  
  has_attached_file :header_tagline_logo,
                    :styles => { :large => "300x150>" },
                    :storage => :cloud_files,
                    :cloudfiles_credentials => "#{Rails.root}/config/rackspace_cloudfiles.yml",
                    :container => CLOUD_FILES_CONTAINER,
                    :path => "#{Rails.env}/:id/header_tagline_logo/:updated_at/:style/:basename.:extension",
                    :ssl => true

  before_validation :set_default_fields, on: :create
  before_validation :downcase_name
  before_validation :set_managed_header_links, :set_managed_footer_links
  before_validation :set_default_labels
  before_validation_squish :ga_web_property_id,
                           :header_tagline_font_size,
                           :logo_alt_text,
                           :navigation_dropdown_label,
                           :related_sites_dropdown_label,
                           assign_nil_on_blank: true
  before_validation :set_api_access_key, unless: :api_access_key?
  validates_presence_of :display_name, :name, :locale, :theme
  validates_uniqueness_of :api_access_key, :name, :case_sensitive => false
  validates_length_of :name, :within => (2..MAX_NAME_LENGTH)
  validates_format_of :name, :with => /^[a-z0-9._-]+$/

  validates_attachment_content_type :page_background_image,
                                    content_type: VALID_IMAGE_CONTENT_TYPES,
                                    message: INVALID_CONTENT_TYPE_MESSAGE
  validates_attachment_size :page_background_image,
                            in: (1..MAXIMUM_IMAGE_SIZE_IN_KB.kilobytes),
                            message: INVALID_IMAGE_SIZE_MESSAGE

  validates_attachment_content_type :header_image,
                                    content_type: VALID_IMAGE_CONTENT_TYPES,
                                    message: INVALID_CONTENT_TYPE_MESSAGE
  validates_attachment_size :header_image,
                            in: (1..MAXIMUM_IMAGE_SIZE_IN_KB.kilobytes),
                            message: INVALID_IMAGE_SIZE_MESSAGE

  validates_attachment_content_type :mobile_logo,
                                    content_type: VALID_IMAGE_CONTENT_TYPES,
                                    message: INVALID_CONTENT_TYPE_MESSAGE
  validates_attachment_size :mobile_logo,
                            in: (1..MAXIMUM_MOBILE_IMAGE_SIZE_IN_KB.kilobytes),
                            message: INVALID_MOBILE_IMAGE_SIZE_MESSAGE

  validates_attachment_content_type :header_tagline_logo,
                                    content_type: VALID_IMAGE_CONTENT_TYPES,
                                    message: INVALID_CONTENT_TYPE_MESSAGE
  validates_attachment_size :header_tagline_logo,
                            in: (1..MAXIMUM_HEADER_TAGLINE_LOGO_IMAGE_SIZE_IN_KB.kilobytes),
                            message: INVALID_HEADER_TAGLINE_LOGO_IMAGE_SIZE_MESSAGE

  validate :html_columns_cannot_be_malformed,
           :validate_css_property_hash,
           :validate_managed_footer_links,
           :validate_managed_header_links,
           :validate_staged_header_footer,
           :validate_staged_header_footer_css,
           :language_valid

  after_validation :update_error_keys
  before_save :ensure_http_prefix
  before_save :set_css_properties, :generate_look_and_feel_css, :sanitize_staged_header_footer, :set_json_fields, :set_search_labels
  before_create :set_keen_scoped_key
  before_update :clear_existing_attachments
  after_create :normalize_site_domains
  after_destroy :remove_boosted_contents_from_index

  scope :ordered, { :order => 'display_name ASC' }
  attr_writer :css_property_hash
  attr_protected :previous_fields_json, :live_fields_json, :staged_fields_json, :is_validate_staged_header_footer
  attr_accessor :mark_page_background_image_for_deletion, :mark_header_image_for_deletion, :mark_mobile_logo_for_deletion, :mark_header_tagline_logo_for_deletion
  attr_accessor :is_validate_staged_header_footer
  attr_accessor :managed_header_links_attributes, :managed_footer_links_attributes

  accepts_nested_attributes_for :site_domains, :reject_if => :all_blank
  accepts_nested_attributes_for :image_search_label
  accepts_nested_attributes_for :rss_feeds
  accepts_nested_attributes_for :document_collections, :reject_if => :all_blank
  accepts_nested_attributes_for :connections, :allow_destroy => true, :reject_if => proc { |a| a[:affiliate_name].blank? and a[:label].blank? }
  accepts_nested_attributes_for :flickr_profiles, :allow_destroy => true
  accepts_nested_attributes_for :facebook_profiles, :allow_destroy => true
  accepts_nested_attributes_for :twitter_profiles, :allow_destroy => false

  USAGOV_AFFILIATE_NAME = 'usagov'
  GOBIERNO_AFFILIATE_NAME = 'gobiernousa'

  DEFAULT_SEARCH_RESULTS_PAGE_TITLE = "{Query} - {SiteName} Search Results"
  BANNED_HTML_ELEMENTS_FROM_HEADER_AND_FOOTER = %w(form script style link)

  HUMAN_ATTRIBUTE_NAME_HASH = {
    :display_name => "Display name",
    :name => "Site Handle (visible to searchers in the URL)",
    :header_image_file_size => 'Legacy Logo file size',
    :mobile_logo_file_size => 'Logo file size',
    :mobile_header_tagline_logo_file_size => 'Header Tagline Logo file size',
    :page_background_image_file_size => 'Page Background Image file size'
  }

  BACKGROUND_REPEAT_VALUES = %w(no-repeat repeat repeat-x repeat-y)

  THEMES = ActiveSupport::OrderedHash.new
  THEMES[:default] = {
    content_background_color: '#FFFFFF',
    content_border_color: '#CACACA',
    content_box_shadow_color: '#555555',
    description_text_color: '#000000',
    footer_background_color: '#DFDFDF',
    header_background_color: '#FFFFFF',
    header_tagline_background_color: '#000000',
    header_tagline_color: '#FFFFFF',
    search_button_text_color: '#FFFFFF',
    search_button_background_color: '#00396F',
    left_tab_text_color: '#9E3030',
    navigation_background_color: '#F1F1F1',
    navigation_link_color: '#505050',
    page_background_color: '#DFDFDF',
    title_link_color: '#2200CC',
    url_link_color: '#006800',
    visited_title_link_color: '#800080' }

  THEMES[:custom] = { :display_name => 'Custom' }

  DEFAULT_CSS_PROPERTIES = {
    font_family: FontFamily::DEFAULT,
    header_tagline_font_family: HeaderTaglineFontFamily::DEFAULT,
    header_tagline_font_size: '1.3em',
    header_tagline_font_style: 'italic',
    logo_alignment: LogoAlignment::DEFAULT,
    show_content_border: '0',
    show_content_box_shadow: '0',
    page_background_image_repeat: BACKGROUND_REPEAT_VALUES[0] }.merge(THEMES[:default])

  ATTRIBUTES_WITH_STAGED_AND_LIVE = %w(header footer header_footer_css nested_header_footer_css uses_managed_header_footer)

  CUSTOM_INDEXING_LANGUAGES = %w(en es)

  COMMON_INDEXING_LANGUAGE = 'babel'

  def indexing_locale
    CUSTOM_INDEXING_LANGUAGES.include?(self.locale) ? self.locale : COMMON_INDEXING_LANGUAGE
  end

  def self.define_hash_columns_accessors(args)
    column_name_method = args[:column_name_method]
    fields = args[:fields]

    fields.each do |field|
      define_method field do
        self.send(column_name_method).send("[]", field)
      end

      define_method :"#{field}=" do |arg|
        self.send(column_name_method).send("[]=", field, arg)
      end
    end
  end

  define_hash_columns_accessors column_name_method: :previous_fields, fields: [:previous_header, :previous_footer]
  define_hash_columns_accessors column_name_method: :live_fields,
                                fields: [:header, :footer,
                                         :header_footer_css, :nested_header_footer_css,
                                         :managed_header_links, :managed_footer_links,
                                         :external_tracking_code, :submitted_external_tracking_code,
                                         :look_and_feel_css, :mobile_look_and_feel_css,
                                         :logo_alt_text, :sitelink_generator_names,
                                         :header_tagline,
                                         :header_tagline_url,
                                         :page_one_more_results_pointer, :no_results_pointer,
                                         :footer_fragment,
                                         :navigation_dropdown_label, :related_sites_dropdown_label]
  define_hash_columns_accessors column_name_method: :staged_fields,
                                fields: [:staged_header, :staged_footer,
                                         :staged_header_footer_css, :staged_nested_header_footer_css]

  serialize :dublin_core_mappings, Hash
  define_hash_columns_accessors column_name_method: :dublin_core_mappings,
                                fields: [:dc_contributor, :dc_publisher, :dc_subject]

  define_hash_columns_accessors column_name_method: :css_property_hash,
                                fields: %i(header_tagline_font_family header_tagline_font_size header_tagline_font_style)

  def scope_ids_as_array
    @scope_ids_as_array ||= (self.scope_ids.nil? ? [] : self.scope_ids.split(',').each { |scope| scope.strip! })
  end

  def has_multiple_domains?
    site_domains.count > 1
  end

  def update_attributes_for_staging(attributes)
    set_is_validate_staged_header_footer attributes
    attributes[:has_staged_content] = true
    self.update_attributes(attributes)
  end

  def recent_user_activity
    users.collect(&:last_request_at).compact.max
  end

  def update_attributes_for_live(attributes)
    set_is_validate_staged_header_footer attributes
    transaction do
      if self.update_attributes(attributes)
        self.previous_header = header
        self.previous_footer = footer
        set_attributes_from_staged_to_live
        self.has_staged_content = false
        self.save!
        true
      else
        false
      end
    end
  end

  def push_staged_changes
    self.previous_header = header
    self.previous_footer = footer
    set_attributes_from_staged_to_live
    self.has_staged_content = false
    save!
  end

  def cancel_staged_changes
    set_attributes_from_live_to_staged
    self.has_staged_content = false
    save!
  end

  def sync_staged_attributes
    self.cancel_staged_changes unless self.has_staged_content?
  end

  def has_changed_header_or_footer
    self.header != self.previous_header or self.footer != self.previous_footer
  end

  class << self
    def human_attribute_name(attribute_key_name, options = {})
      HUMAN_ATTRIBUTE_NAME_HASH[attribute_key_name.to_sym] || super
    end
  end

  def css_property_hash(reload = false)
    @css_property_hash = nil if reload
    if theme.to_sym == :default
      @css_property_hash ||= THEMES[:default].reverse_merge(load_css_properties)
    else
      @css_property_hash ||= load_css_properties
    end
  end

  def add_site_domains(site_domain_param_hash)
    transaction do
      added_site_domains = site_domain_param_hash.map do |domain, site_name|
        site_domain = site_domains.build(domain: domain, site_name: site_name)
        site_domain if site_domain.save
      end.compact
      normalize_site_domains
      site_domains.where(id: added_site_domains.map(&:id))
    end
  end

  def update_site_domain(site_domain, site_domain_attributes)
    transaction do
      normalize_site_domains if site_domain.update_attributes(site_domain_attributes)
    end
  end

  def normalize_site_domains
    all_site_domains = site_domains(true).sort { |a, b| a.domain.length <=> b.domain.length }
    all_site_domains.each { |domain| domain.destroy unless domain.valid? }
  end

  def show_content_border?
    css_property_hash[:show_content_border] == '1'
  end

  def show_content_box_shadow?
    css_property_hash[:show_content_box_shadow] == '1'
  end

  def set_attributes_from_live_to_staged
    ATTRIBUTES_WITH_STAGED_AND_LIVE.each do |field|
      self.send("staged_#{field}=", self.send("#{field}"))
    end
  end

  def set_attributes_from_staged_to_live
    ATTRIBUTES_WITH_STAGED_AND_LIVE.each do |field|
      self.send("#{field}=", self.send("staged_#{field}"))
    end
  end

  def refresh_indexed_documents(scope)
    indexed_documents.select(:id).send(scope.to_sym).find_in_batches(:batch_size => batch_size(scope)) do |batch|
      Resque.enqueue_with_priority(:low, AffiliateIndexedDocumentFetcher, id, batch.first.id, batch.last.id, scope)
    end
  end

  def sanitized_header
    sanitize_html header
  end

  def sanitized_footer
    sanitize_html footer
  end

  def use_strictui
    self.header = sanitized_header
    self.footer = sanitized_footer
    self.external_css_url = nil
  end

  def unused_features
    features.any? ? Feature.where('id not in (?)', features.collect(&:id)) : Feature.all
  end

  def excludes_url?(url)
    @excluded_urls_set ||= self.excluded_urls.collect(&:url).to_set
    decoded_url = URI.decode_www_form_component url rescue nil
    @excluded_urls_set.include?(decoded_url)
  end

  def has_organization_codes?
    agency.present? && agency.agency_organization_codes.any?
  end

  def should_show_job_organization_name?
    agency.blank? || agency.agency_organization_codes.empty? ||
      agency.agency_organization_codes.all? { |organization_code| organization_code.is_department_level? }
  end

  def default_autodiscovery_url
    if website.present?
      website
    elsif site_domains.count == 1
      "http://#{site_domains.pluck(:domain).first}"
    end
  end

  def has_no_social_image_feeds?
    flickr_profiles.empty? && instagram_profiles.empty? &&
      (rss_feeds.mrss.empty? || rss_feeds.mrss.collect(&:rss_feed_urls).flatten.collect(&:oasis_mrss_name).compact.empty?)
  end

  def has_social_image_feeds?
    !has_no_social_image_feeds?
  end

  def searchable_twitter_ids
    affiliate_twitter_settings.includes(:twitter_profile).map do |ats|
      twitter_ids = [ats.twitter_profile.twitter_id]
      twitter_ids.push(ats.twitter_profile.twitter_lists.map(&:member_ids)) if ats.show_lists?
      twitter_ids
    end.flatten.uniq
  end

  def destroy_and_update_attributes(params)
    destroy_on_blank(params[:connections_attributes], :affiliate_name, :label)
    update_attributes(params)
  end

  def enable_video_govbox!
    transaction do
      rss_feed = rss_feeds.managed.first_or_initialize(name: I18n.t(:videos, locale: locale))
      rss_feed.save!
      update_column(:is_video_govbox_enabled, true)
    end
  end

  def disable_video_govbox!
    transaction do
      rss_feed = rss_feeds.managed.first
      rss_feed.destroy if rss_feed
      update_column(:is_video_govbox_enabled, false)
    end
  end

  def uses_custom_theme?
    theme != 'default'
  end

  def mobile_logo_url
    mobile_logo.url rescue 'unable to retrieve mobile logo url' if mobile_logo_file_name.present?
  end

  def header_image_url
    header_image.url rescue 'unable to retrieve header image url' if header_image_file_name.present?
  end

  def last_month_query_count
    prev_month = Date.current.prev_month
    count_query = CountQuery.new(name)
    RtuCount.count("human-logstash-#{prev_month.strftime("%Y.%m.")}*", 'search', count_query.body)
  end

  def user_emails
    users.map(&:to_label).join(',')
  end

  def assign_sitelink_generator_names!
    self.sitelink_generator_names = SitelinkGeneratorUtils.matching_generator_names site_domains.pluck(:domain)
    save!
  end

  def to_label
    "##{id} #{display_name} (#{display_name}) [#{status.name}]"
  end

  private

  def batch_size(scope)
    (indexed_documents.send(scope.to_sym).size / fetch_concurrency.to_f).ceil
  end

  def remove_boosted_contents_from_index
    boosted_contents.each { |bs| bs.remove_from_index }
  end

  def downcase_name
    self.name = name.downcase if name.present?
  end

  def set_default_labels
    self.rss_govbox_label = I18n.t(:default_rss_govbox_label, locale: locale) if rss_govbox_label.blank?
  end

  def ensure_http_prefix
    set_http_prefix :favicon_url, :external_css_url, :website
  end

  def validate_css_property_hash
    unless @css_property_hash.blank?
      validate_font_family @css_property_hash
      validate_logo_alignment @css_property_hash
      validate_color_in_css_property_hash @css_property_hash
    end
  end

  def validate_font_family(hash)
    errors.add(:base, "Font family selection is invalid") if hash['font_family'].present? and !FontFamily.valid?(hash['font_family'])
  end

  def validate_logo_alignment(hash)
    errors.add(:base, 'Logo alignment is invalid') if hash['logo_alignment'].present? and !LogoAlignment.valid?(hash['logo_alignment'])
  end

  def validate_color_in_css_property_hash(hash)
    unless hash.blank?
      DEFAULT_CSS_PROPERTIES.keys.each do |key|
        validate_color_property(key, hash[key])
      end
    end
  end

  def validate_color_property(key, value)
    return unless key.to_s =~ /color$/ and value.present?
    errors.add(:base, "#{key.to_s.humanize} should consist of a # character followed by 3 or 6 hexadecimal digits") unless value =~ /^#([a-fA-F0-9]{6}|[a-fA-F0-9]{3})$/
  end

  def set_managed_header_links
    return if @managed_header_links_attributes.nil?
    self.managed_header_links = []
    set_managed_links(@managed_header_links_attributes, managed_header_links)
  end

  def set_managed_footer_links
    return if @managed_footer_links_attributes.nil?
    self.managed_footer_links = []
    set_managed_links(@managed_footer_links_attributes, managed_footer_links)
  end

  def set_managed_links(managed_links_attributes, managed_links)
    managed_links_attributes.values.sort_by { |link| link[:position].to_i }.each do |link|
      next if link[:title].blank? and link[:url].blank?
      url = link[:url]
      url = "http://#{url}" if url.present? and url !~ %r{^(http(s?)://|mailto:)}i
      managed_links << { :position => link[:position].to_i, :title => link[:title], :url => url }
    end
  end

  def validate_managed_header_links
    validate_managed_links(managed_header_links, :header)
  end

  def validate_managed_footer_links
    validate_managed_links(managed_footer_links, :footer)
  end

  def validate_managed_links(links, link_type)
    return if links.blank?
    add_blank_link_title_error = false
    add_blank_link_url_error = false
    links.each do |link|
      add_blank_link_title_error = true if link[:title].blank? and link[:url].present?
      add_blank_link_url_error = true if link[:title].present? and link[:url].blank?
    end
    errors.add(:base, "#{link_type.to_s.humanize} link title can't be blank") if add_blank_link_title_error
    errors.add(:base, "#{link_type.to_s.humanize} link URL can't be blank") if add_blank_link_url_error
  end

  def set_default_fields
    self.theme = THEMES.keys.first.to_s if theme.blank?
    self.uses_managed_header_footer = true if uses_managed_header_footer.nil?
    self.staged_uses_managed_header_footer = true if staged_uses_managed_header_footer.nil?
    @css_property_hash = ActiveSupport::OrderedHash.new if @css_property_hash.nil?
  end

  def set_css_properties
    self.css_properties = @css_property_hash.to_json unless @css_property_hash.blank?
  end

  def validate_staged_header_footer_css
    return unless is_validate_staged_header_footer
    begin
      self.staged_nested_header_footer_css = generate_nested_css(staged_header_footer_css)
    rescue Sass::SyntaxError => err
      errors.add(:base, "CSS for the top and bottom of your search results page: #{err}")
    end
  end

  def language_valid
    errors.add(:base, "Locale must be valid") unless Language.exists?(code: self.locale)
  end

  def generate_nested_css(css)
    Renderers::CssToNestedCss.new('.header-footer', css).render if css.present?
  end

  def validate_staged_header_footer
    return unless is_validate_staged_header_footer
    validate_header_results = validate_html staged_header
    if validate_header_results[:has_malformed_html]
      errors.add(:base, malformed_html_error_message(:top))
    end

    if validate_header_results[:has_banned_elements]
      errors.add(:base, "HTML to customize the top of your search results page must not contain #{BANNED_HTML_ELEMENTS_FROM_HEADER_AND_FOOTER.join(', ')} elements.")
    end

    if validate_header_results[:has_banned_attributes]
      errors.add(:base, "HTML to customize the top of your search results page must not contain the onload attribute.")
    end

    validate_footer_results = validate_html staged_footer
    if validate_footer_results[:has_malformed_html]
      errors.add(:base, malformed_html_error_message(:bottom))
    end

    if validate_footer_results[:has_banned_elements]
      errors.add(:base, "HTML to customize the bottom of your search results page must not contain #{BANNED_HTML_ELEMENTS_FROM_HEADER_AND_FOOTER.join(', ')} elements.")
    end

    if validate_footer_results[:has_banned_attributes]
      errors.add(:base, "HTML to customize the bottom of your search results page must not contain the onload attribute.")
    end
  end

  def html_columns_cannot_be_malformed
    %i(external_tracking_code footer_fragment).each do |field_name_symbol|
      value = self.send field_name_symbol
      next if value.blank?

      validation_results = validate_html value
      if validation_results[:has_malformed_html]
        errors.add(:base, "#{field_name_symbol.to_s.humanize} is invalid: #{validation_results[:error_message]}")
      end
    end
  end

  def validate_html(html)
    validate_html_results = {}
    has_banned_elements = false
    has_banned_attributes = false
    unless html.blank?
      html_doc = Nokogiri::HTML::DocumentFragment.parse html
      unless html_doc.errors.empty?
        validate_html_results[:has_malformed_html] = true
        validate_html_results[:error_message] = html_doc.errors.join('. ') + '.' unless html_doc.errors.blank?
      end
      has_banned_elements = true unless html_doc.css(BANNED_HTML_ELEMENTS_FROM_HEADER_AND_FOOTER.join(',')).blank?
      has_banned_attributes = true unless html_doc.xpath('*[@onload]').blank?
    end
    validate_html_results[:has_banned_elements] = has_banned_elements
    validate_html_results[:has_banned_attributes] = has_banned_attributes
    validate_html_results
  end

  def malformed_html_error_message(field_name)
    email_link = %Q{<a href="mailto:#{SUPPORT_EMAIL_ADDRESS}">#{SUPPORT_EMAIL_ADDRESS}</a>}
    "HTML to customize the #{field_name.to_s} of your search results is invalid. Click on the validate link below or email us at #{email_link}".html_safe
  end

  def sanitize_html(html)
    unless html.blank?
      doc = Nokogiri::HTML::DocumentFragment.parse html
      doc.css("#{BANNED_HTML_ELEMENTS_FROM_HEADER_AND_FOOTER.join(',')}").each(&:remove)
      doc.to_html
    end
  end

  def update_error_keys
    swap_error_key(:"rss_feeds.base", :base)
    swap_error_key(:"site_domains.domain", :domain)
    swap_error_key(:"connections.connected_affiliate_id", :related_site_handle)
    swap_error_key(:"connections.label", :related_site_label)
    swap_error_key(:staged_page_background_image_file_size, :page_background_image_file_size)
    swap_error_key(:staged_header_image_file_size, :header_image_file_size)
  end

  def previous_fields
    @previous_fields ||= previous_fields_json.blank? ? {} : JSON.parse(previous_fields_json, :symbolize_names => true)
  end

  def live_fields
    @live_fields ||= live_fields_json.blank? ? {} : JSON.parse(live_fields_json, :symbolize_names => true)
  end

  def staged_fields
    @staged_fields ||= staged_fields_json.blank? ? {} : JSON.parse(staged_fields_json, :symbolize_names => true)
  end

  def set_json_fields
    self.previous_fields_json = ActiveSupport::OrderedHash[previous_fields.sort].to_json
    self.live_fields_json = ActiveSupport::OrderedHash[live_fields.sort].to_json
    self.staged_fields_json = ActiveSupport::OrderedHash[staged_fields.sort].to_json
  end

  def load_css_properties
    return {} if css_properties.blank?
    JSON.parse(css_properties, :symbolize_names => true)
  end

  def clear_existing_attachments
    if page_background_image? and !page_background_image.dirty? and mark_page_background_image_for_deletion == '1'
      page_background_image.clear
    end

    if header_image? and !header_image.dirty? and mark_header_image_for_deletion == '1'
      header_image.clear
    end

    if mobile_logo? and !mobile_logo.dirty? and mark_mobile_logo_for_deletion == '1'
      mobile_logo.clear
    end

    if header_tagline_logo? and !header_tagline_logo.dirty? and mark_header_tagline_logo_for_deletion == '1'
      header_tagline_logo.clear
    end
  end

  def set_search_labels
    self.default_search_label = I18n.t(:everything, locale: locale) if default_search_label.blank?
  end

  def set_keen_scoped_key
    self.keen_scoped_key = KeenScopedKey.generate(self.id)
  end

  def set_api_access_key
    self.api_access_key = Digest::SHA256.base64digest("#{name}:#{Time.current.to_i}:#{rand}").tr('+/', '-_')
  end

  def sanitize_staged_header_footer
    self.staged_header = strip_comments(staged_header) unless staged_header.blank?
    self.staged_footer = strip_comments(staged_footer) unless staged_footer.blank?
  end

  def set_is_validate_staged_header_footer(attributes)
    self.is_validate_staged_header_footer = attributes[:staged_uses_managed_header_footer] == '0'
  end

  def generate_look_and_feel_css
    renderer = Renderers::AffiliateCss.new(build_css_hash)
    self.look_and_feel_css = renderer.render_desktop_css
    self.mobile_look_and_feel_css = renderer.render_mobile_css
  end

  def build_css_hash
    css_hash = {}
    css_hash.merge!(css_property_hash) if css_property_hash(true)
    css_hash
  end

  def self.to_name_site_hash
    Hash[all.collect { |site| [site.name, site] }]
  end

end
