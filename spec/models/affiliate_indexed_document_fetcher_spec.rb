require 'spec/spec_helper'

describe AffiliateIndexedDocumentFetcher, "#perform(affiliate_id, start_id, end_id)" do
  fixtures :affiliates
  before do
    IndexedDocument.destroy_all
    @affiliate = affiliates(:basic_affiliate)
    @first = @affiliate.indexed_documents.build(:title => 'PDF Title',
                                                :description => 'This is a PDF document.',
                                                :url => 'http://something.gov/pdf.pdf',
                                                :last_crawl_status => IndexedDocument::OK_STATUS,
                                                :body => "this is the doc body",
                                                :content_hash => "a6e450cc50ac3b3b7788b50b3b73e8b0b7c197c8")
    @second = @affiliate.indexed_documents.build(:url => 'http://some.mil/foo')
    @affiliate.indexed_documents.build(:url => 'http://some.mil/i_should_be_ignored')
    @affiliate.save!
  end

  it "should attempt to fetch and index the documents between start_id and end_id that belong to that affiliate" do
    Affiliate.should_receive(:find).with(@affiliate.id).and_return @affiliate
    idocs = @affiliate.indexed_documents
    @affiliate.should_receive(:indexed_documents).twice.and_return idocs
    idocs.should_receive(:find_each).with(:batch_size => 100, :conditions => ["last_crawl_status <> 'OK' and id between ? and ?", @first.id, @second.id]).and_yield(@second)
    idocs.should_receive(:find_each).with(:batch_size => 100, :conditions => ["last_crawl_status == 'OK' and id between ? and ?", @first.id, @second.id]).and_yield(@first)
    @first.should_receive(:fetch)
    @second.should_receive(:fetch)
    AffiliateIndexedDocumentFetcher.perform(@affiliate.id, @first.id, @second.id)
  end
end