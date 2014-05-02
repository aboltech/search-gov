class ElasticNewsItem
  extend Indexable
  DUBLIN_CORE_AGG_NAMES = [:contributor, :subject, :publisher]

  self.settings = ElasticSettings::COMMON

  self.mappings = {
    index_type => {
      dynamic: :strict,
      _analyzer: { path: "language" },
      properties: {
        language: { type: "string", index: :not_analyzed },
        rss_feed_url_id: { type: 'integer' },
        title: { type: 'string', term_vector: 'with_positions_offsets' },
        description: { type: 'string', term_vector: 'with_positions_offsets' },
        published_at: { type: 'date' },
        popularity: { type: 'integer' },
        link: ElasticSettings::KEYWORD,
        contributor: { type: 'string', analyzer: 'keyword' },
        subject: { type: 'string', analyzer: 'keyword' },
        publisher: { type: 'string', analyzer: 'keyword' },
        tags: { type: 'string', analyzer: 'keyword' },
        id: { type: 'integer', index: :not_analyzed, include_in_all: false } }
    }
  }

end