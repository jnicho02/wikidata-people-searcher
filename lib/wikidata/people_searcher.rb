require 'wikidata/people-searcher/version'
require 'json'
require 'logger'
require 'open-uri'
require 'ostruct'

module Wikidata
  # use default Logger, or assign your own
  class << self
    attr_writer :logger

    def logger
      @logger ||= Logger.new($stdout).tap do |log|
        log.progname = self.name
      end
    end
  end

  # Wikidata has structure "entities": {"Q123": { ... }}
  # The Q code is unknown to us in advance
  class WikidataStruct < OpenStruct
    def date_of_birth
      q&.claims&.P569&.first&.mainsnak&.datavalue&.value&.time
    end

    def date_of_death
      q&.claims&.P570&.first&.mainsnak&.datavalue&.value&.time
    end

    def disambiguation?
      q&.descriptions&.en&.value&.to_s&.include?('disambiguation page')
    end

    def scientific_article?
      q&.descriptions&.en&.value&.to_s&.include?('scientific article')
    end

    def ignorable?
      not_found? || disambiguation? || scientific_article?
    end

    def not_found?
      qcode == '-1'
    end

    def qcode
      entities&.root_key&.to_s
    end

    def q
      entities&.send(qcode.to_s)
    end

    def root_key
      @table.keys.first
    end
  end

  # A Wikidata object has much information in the open graph
  class PeopleSearcher
    def initialize(wikidata_id)
      return unless wikidata_id&.match(/Q\d*$/)

      root = 'https://www.wikidata.org/w/api.php'
      api = "#{root}?action=wbgetentities&ids=#{wikidata_id}&format=json"
      Wikidata.logger.debug(api)
      response = URI.parse(api).open
      resp = response.read
      @wikidata = JSON.parse(resp, object_class: WikidataStruct)
    end

    def born_in
      return if !@wikidata

      t = @wikidata.date_of_birth
      # can be +1600-00-00 for 'unknown month and day' which breaks datetime

      return unless t&.match(/\+(\d\d\d\d)/)

      t.match(/\+(\d\d\d\d)/)[1]
    end

    def died_in
      return if !@wikidata

      t = @wikidata.date_of_death
      t.match(/\+(\d\d\d\d)/)[1] if t&.match(/\+(\d\d\d\d)/)
    end

    def dates?(born, died)
      return false if ignorable?
      return false unless (present?(born) && present?(born_in)) || (present?(died) && present?(died_in))

      Wikidata.logger.debug("#{qcode} (#{born}-#{died}) == (#{born_in}-#{died_in})")
      b_match = present?(born) && present?(born_in) ? born == born_in : true
      d_match = present?(died) && present?(died_in) ? died == died_in : true
      b_match && d_match
    end

    def ignorable?
      @wikidata&.ignorable?
    end

    def not_found?
      @wikidata&.not_found?
    end

    def present?(obj)
      !(obj.respond_to?(:empty?) ? !!obj.empty? : !obj)
    end

    def qcode
      @wikidata&.qcode
    end

    def self.qcode(term)
      term = term.tr(
        "’ß#ÀÁÂÃÄÅàáâãäåĀāĂăĄąÇçĆćĈĉĊċČčÐðĎďĐđÈÉÊËèéêëĒēĔĕĖėĘęĚěĜĝĞğĠġĢģĤĥĦħÌÍÎÏìíîïĨĩĪīĬĭĮįİıĴĵĶķĸĹĺĻļĽľĿŀŁłÑñŃńŅņŇňŉŊŋÒÓÔÕÖØòóôõöøŌōŎŏŐőŔŕŖŗŘřŚśŜŝŞşŠšſŢţŤťŦŧÙÚÛÜùúûüŨũŪūŬŭŮůŰűŲųŴŵÝýÿŶŷŸŹźŻżŽž",
        "'s AAAAAAaaaaaaAaAaAaCcCcCcCcCcDdDdDdEEEEeeeeEeEeEeEeEeGgGgGgGgHhHhIIIIiiiiIiIiIiIiIiJjKkkLlLlLlLlLlNnNnNnNnnNnOOOOOOooooooOoOoOoRrRrRrSsSsSsSssTtTtTtUUUUuuuuUuUuUuUuUuUuWwYyyYyYZzZzZz"
      )
      api_root = 'https://www.wikidata.org/w/api.php?action='
      name_and_dates = term.match(/(.*) \((\d\d\d\d)\s*-*\s*(\d\d\d\d)\)/)
      if name_and_dates
        name = name_and_dates[1]
        born = name_and_dates[2]
        died = name_and_dates[3]
      else
        name_and_dates = term.match(/(.*) \(d.\s*-*\s*(\d\d\d\d)\)/)
        if name_and_dates
          name = name_and_dates[1]
          died = name_and_dates[2]
        else
          name_and_dates = term.match(/(.*) \(b.\s*-*\s*(\d\d\d\d)\)/)
          if name_and_dates
            name = name_and_dates[1]
            born = name_and_dates[2]
          else
            name = term
          end
        end
      end
      begin
        api = "#{api_root}wbgetentities&sites=enwiki&titles=#{name}&format=json"
        Wikidata.logger.debug(api)
        response = URI.parse(api).open
        resp = response.read
        wikidata = JSON.parse(resp, object_class: WikidataStruct)
        if wikidata.not_found?
          #  try again with first letter in uppercase
          name = name[0].upcase + name[1..]
          api = "#{api_root}wbgetentities&sites=enwiki&titles=#{name}&format=json"
          Wikidata.logger.debug(api)
          response = URI.parse(api).open
          resp = response.read
          wikidata = JSON.parse(resp, object_class: WikidataStruct)
        end
        if wikidata.ignorable? && (born || died)
          api = "#{api_root}query&list=search&srsearch=#{name}&format=json"
          Wikidata.logger.debug(api)
          response = URI.parse(api).open
          resp = response.read
          search_wikidata = JSON.parse(resp, object_class: WikidataStruct)
          search_wikidata.query.search.each do |search_result|
            w = PeopleSearcher.new(search_result.title)
            return w.qcode if w.dates?(born, died)
          end
        end
        if wikidata.ignorable?
          nil
        elsif born || died
          w = PeopleSearcher.new(wikidata.qcode)
          w.qcode if w.dates?(born, died)
        else
          wikidata.qcode
        end
      rescue URI::InvalidURIError
        Wikidata.logger.error 'nasty char in there'
      end
    end

    def en_wikipedia_url
      return if !@wikidata || @wikidata.ignorable?

      t = @wikidata&.q&.sitelinks&.enwiki&.title
      "https://en.wikipedia.org/wiki/#{t.gsub(' ', '_')}" if t
    end
  end
end
