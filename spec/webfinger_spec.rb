require 'spec_helper'

describe WebFinger do
  let(:resource) { 'acct:nov@example.com' }

  describe '#discover!' do
    shared_examples_for :discovery_succeeded do
      it 'should return WebFinger::Response' do
        mock_json 'https://example.com/.well-known/webfinger', 'all', query: {resource: resource} do
          response = WebFinger.discover! resource
          response.should be_instance_of WebFinger::Response
        end
      end
    end

    [:acct, :mailto, :device, :unknown].each do |scheme|
      context "with #{scheme} scheme" do
        let(:resource) { "#{scheme}:nov@example.com" }
        it_behaves_like :discovery_succeeded
      end
    end

    context 'with http scheme' do
      let(:resource) { 'http://example.com/nov' }
      it_behaves_like :discovery_succeeded
    end

    context 'with https scheme' do
      let(:resource) { 'https://example.com/nov' }
      it_behaves_like :discovery_succeeded
    end

    context 'with host option' do
      it 'should use given host' do
        mock_json 'https://discover.example.com/.well-known/webfinger', 'all', query: {resource: resource} do
          response = WebFinger.discover! resource, host: 'discover.example.com'
          response.should be_instance_of WebFinger::Response
        end
      end
    end

    context 'with port option' do
      it 'should use given port' do
        mock_json 'https://example.com:8080/.well-known/webfinger', 'all', query: {resource: resource} do
          response = WebFinger.discover! resource, port: 8080
          response.should be_instance_of WebFinger::Response
        end
      end
    end

    context 'with rel option' do
      shared_examples_for :discovery_with_rel do
        let(:query_string) do
          query_params = [{resource: resource}.to_query]
          Array(rel).each do |_rel_|
            query_params << {rel: _rel_}.to_query
          end
          query_params.join('&')
        end

        it 'should request with rel' do
          query_string.scan('rel').count.should == Array(rel).count
          mock_json 'https://example.com/.well-known/webfinger', 'all', query: query_string do
            response = WebFinger.discover! resource, rel: rel
            response.should be_instance_of WebFinger::Response
          end
        end
      end

      context 'when single rel' do
        let(:rel) { 'http://openid.net/specs/connect/1.0/issuer' }
        it_behaves_like :discovery_with_rel
      end

      context 'when multiple rel' do
        let(:rel) { ['http://openid.net/specs/connect/1.0/issuer', 'vcard'] }
        it_behaves_like :discovery_with_rel
      end
    end

    context 'when error' do
      {
        400 => WebFinger::BadRequest,
        401 => WebFinger::Unauthorized,
        403 => WebFinger::Forbidden,
        404 => WebFinger::NotFound,
        500 => WebFinger::HttpError
      }.each do |status, exception_class|
        context "when status=#{status}" do
          it "should raise #{exception_class}" do
            expect do
              mock_json 'https://example.com/.well-known/webfinger', 'all', query: {resource: resource}, status: [status, 'HTTPError'] do
                response = WebFinger.discover! resource
              end
            end.to raise_error exception_class
          end
        end
      end
    end
  end

  describe '#cache' do
    subject { WebFinger.cache }

    context 'as default' do
      it { should be_instance_of WebFinger::Cache }
    end

    context 'when specified' do
      let(:cacher) { 'Rails.cache or something' }
      before { WebFinger.cache = cacher }
      it { should == cacher }
    end
  end

  describe '#logger' do
    subject { WebFinger.logger }

    context 'as default' do
      it { should be_instance_of Logger }
    end

    context 'when specified' do
      let(:logger) { 'Rails.logger or something' }
      before { WebFinger.logger = logger }
      it { should == logger }
    end
  end

  describe '#debugging?' do
    subject { WebFinger.debugging? }

    context 'as default' do
      it { should be_false }
    end

    context 'when debugging' do
      before { WebFinger.debug! }
      it { should be_true }

      context 'when debugging mode canceled' do
        before { WebFinger.debugging = false }
        it { should be_false }
      end
    end
  end

  describe '#url_builder' do
    subject { WebFinger.url_builder }

    context 'as default' do
      it { should == URI::HTTPS }
    end

    context 'when specified' do
      let(:url_builder) { 'URI::HTTP or something' }
      before { WebFinger.url_builder = url_builder }
      it { should == url_builder }
    end
  end

  describe '#http_client' do
    subject { WebFinger.http_client }

    describe '#request_filter' do
      subject { WebFinger.http_client.request_filter.collect(&:class) }

      context 'as default' do
        it { should_not include WebFinger::Debugger::RequestFilter }
      end

      context 'when debugging' do
        before { WebFinger.debug! }
        it { should include WebFinger::Debugger::RequestFilter }
      end
    end
  end
end