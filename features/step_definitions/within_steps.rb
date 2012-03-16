{
  'in the logo' => '#top_logo',
  'in the header' => '.header',
  'in the affiliate program dropdown menu' => '.affiliate-li',
  'in the api dropdown menu' => '.api-li',
  'in the main navigation bar' => '#main_nav',
  'in the site navigation bar' => '.affiliate-sidebar',
  'in the breadcrumbs' => '.breadcrumbs',
  'in the page header' => 'h1',
  'in the mobile page header' => 'h1.page-title',
  'in the connect section' => '.connect',
  'in the footer' => '.footer',
  'in the query search results table header' => '.query_search_results_table_header',
  'in the callout boxes' => '.col-2',
  'in the side note boxes' => '.column-2',
  'in the search navigation' => '#main_nav',
  'in the homepage header' => '.header',
  'in the homepage footer' => '.footer',
  'in the homepage about section' => '.about',
  'in the homepage tagline' => '.tagline',
  'in the popular urls section' => '#popular_urls',
  'in the left column' => '#left_column',
  'in the selected vertical navigation' => '#sidebar span',
  'in the search results section' => '#results',
  'in the no results section' => '.no-results',
  'in the featured collections section' => '.featured-collections',
  'in the document collections section' => '.document-collections',
  'in the pagination' => '.pagination',
  'in the affiliate boosted contents section' => '.boosted-contents',
  'in the boosted contents section' => '#boosted',
  'in the mobile boosted contents section' => '#boostedresults',
  'in the uncrawled URL list' => '.uncrawled-url-list',
  'in the previously crawled URL list' => '.crawled-url-list',
  'in the indexed documents section' => '#indexed_documents',
  'in the medline govbox' => '.medline',
  'in the agency govbox' => '.agency',
  'in the SERP header' => '#header',
  'in the SERP footer' => '#footer',
  'in the page content' => '.content',
  'in the API key box' => '.content-box',
  'in the API TOS section' => '.api.tos',
  'in the registration form' => 'form#new_user',
  'in the rss feed govbox' => '#indexed_documents'
}.
  each do |within, selector|
    Then /^(.+) #{within}$/ do |step|
      if step =~ /^I (should|should not) see/
        Then %{#{step} within "#{selector}"}
      else
        within(selector) do
          Then step
        end
      end
    end
  end

{
  'in the new user form' => '#new_user',
  'in the login form' => '#new_user_session'
}.
  each do |within, selector|
    When /^I fill in the following #{within}:$/ do |fields|
      within(selector) do
        fields.rows_hash.each do |name, value|
          When %{I fill in "#{name}" with "#{value}"}
        end
      end
    end
  end
