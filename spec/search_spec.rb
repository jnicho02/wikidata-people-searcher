require 'spec_helper'

describe Wikidata::PeopleSearcher do
  describe 'doing a #search' do
    context 'on an unknown term' do
      let(:qcode) {
        VCR.use_cassette("searching/#{self.class.description}".gsub(" ","-")) {
          Wikimedia::PeopleSearcher.search('xauytdfuy')
        }
      }
      it 'should find nothing' do
        expect(qcode).to eq(nil)
      end
    end

    context 'on a known term' do
      let(:titles) {
        VCR.use_cassette("searching/#{self.class.description}".gsub(" ","-")) {
          Wikimedia::PeopleSearcher.search('James Duffy (b.1890)')
        }
      }
      it 'should find some titles' do
        expect(titles.size).to be > 0
      end
    end
  end
end
