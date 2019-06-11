RSpec.describe A9n::Loader do
  let(:scope) { A9n::Scope.new('configuration') }
  let(:env) { 'test' }
  let(:root) { File.expand_path('../../test_app', __dir__) }
  let(:file_path) { File.join(root, 'config/configuration.yml') }
  subject { described_class.new(file_path, scope, env) }

  describe '#intialize' do
    it { expect(subject.scope).to eq(scope) }
    it { expect(subject.env).to eq(env) }
    it { expect(subject.local_file).to eq(file_path) }
    it { expect(subject.example_file).to eq("#{file_path}.example") }
  end

  describe '#load' do
    let(:example_config) do
      { app_url: 'http://127.0.0.1:3000', api_key: 'example1234' }
    end

    let(:local_config) do
      { app_host: '127.0.0.1:3000', api_key: 'local1234' }
    end

    let(:env) { 'tropical' }
    let(:config) { subject.get }

    context 'when no configuration file exists' do
      before do
        expect(described_class).to receive(:load_yml).with(subject.example_file, scope, env).and_return(nil)
        expect(described_class).to receive(:load_yml).with(subject.local_file, scope, env).and_return(nil)
      end

      it 'raises expection' do
        expect {
          subject.load
        }.to raise_error(A9n::MissingConfigurationDataError)
      end
    end

    context 'when only example configuration file exists' do
      before do
        expect(described_class).to receive(:load_yml).with(subject.example_file, scope, env).and_return(example_config)
        expect(described_class).to receive(:load_yml).with(subject.local_file, scope, env).and_return(nil)
        subject.load
      end

      it { expect(config.app_url).to eq('http://127.0.0.1:3000') }
      it { expect(config.api_key).to eq('example1234') }

      it do
        expect { config.app_host }.to raise_error(A9n::NoSuchConfigurationVariableError)
      end
    end

    context 'when only local configuration file exists' do
      before do
        expect(described_class).to receive(:load_yml).with(subject.example_file, scope, env).and_return(nil)
        expect(described_class).to receive(:load_yml).with(subject.local_file, scope, env).and_return(local_config)
        subject.load
      end

      it { expect(config.app_host).to eq('127.0.0.1:3000') }
      it { expect(config.api_key).to eq('local1234') }

      it do
        expect { config.app_url }.to raise_error(A9n::NoSuchConfigurationVariableError)
      end
    end

    context 'when both local and base configuration file exists without defaults' do
      context 'with same data' do
        before do
          expect(described_class).to receive(:load_yml).with(subject.example_file, scope, env).and_return(example_config)
          expect(described_class).to receive(:load_yml).with(subject.local_file, scope, env).and_return(example_config)
          subject.load
        end

        it { expect(config.app_url).to eq('http://127.0.0.1:3000') }
        it { expect(config.api_key).to eq('example1234') }

        it do
          expect { config.app_host }.to raise_error(A9n::NoSuchConfigurationVariableError)
        end
      end

      context 'with different data' do
        before do
          expect(described_class).to receive(:load_yml).with(subject.example_file, scope, env).and_return(example_config)
          expect(described_class).to receive(:load_yml).with(subject.local_file, scope, env).and_return(local_config)
        end

        let(:missing_variables_names) { example_config.keys - local_config.keys }

        it 'raises expection with missing variables names'  do
          expect {
            subject.load
          }.to raise_error(A9n::MissingConfigurationVariablesError, /#{missing_variables_names.join(', ')}/)
        end
      end
    end
  end

  describe '.load_yml' do
    let(:env) { 'test' }
    subject { described_class.load_yml(file_path, scope, env) }

    context 'when file not exists' do
      let(:file_path) { 'file_not_existing_in_the_universe.yml' }

      it { expect(subject).to be_nil }
    end

    context 'when file exists' do
      shared_examples 'non-empty config file' do
        it 'returns non-empty hash' do
          expect(subject).to be_kind_of(Hash)
          expect(subject.keys).to_not be_empty
        end
      end

      before do
        ENV['ERB_DWARF'] = 'erbized dwarf'
        ENV['DWARF_PASSWORD'] = 'dwarf123'
      end

      after do
        ENV.delete('ERB_DWARF')
        ENV.delete('DWARF_PASSWORD')
      end

      context 'when file has erb extension' do
        let(:file_path) { File.join(root, 'config/a9n/cloud.yml.erb') }

        it_behaves_like 'non-empty config file'
      end

      context 'having env and defaults data' do
        let(:file_path) { File.join(root, 'config/configuration.yml') }

        it_behaves_like 'non-empty config file'

        it 'contains keys from defaults scope' do
          expect(subject[:default_dwarf]).to eq('default dwarf')
          expect(subject[:overriden_dwarf]).to eq('already overriden dwarf')
        end

        it 'has symbolized keys' do
          expect(subject.keys.first).to be_kind_of(Symbol)
          expect(subject[:hash_dwarf]).to be_kind_of(Hash)
          expect(subject[:hash_dwarf].keys.first).to be_kind_of(Symbol)
        end

        it 'parses erb' do
          expect(subject[:erb_dwarf]).to eq('erbized dwarf')
        end

        it 'gets valus from ENV' do
          expect(subject[:dwarf_password]).to eq('dwarf123')
        end

        it 'raises exception when ENV var is not set' do
          ENV.delete('DWARF_PASSWORD')
          expect { subject[:dwarf_password] }.to raise_error(A9n::MissingEnvVariableError)
        end

        it 'raises exception when ENV var is set to nil' do
          ENV['DWARF_PASSWORD'] = nil
          expect { subject[:dwarf_password] }.to raise_error(A9n::MissingEnvVariableError)
        end
      end

      context 'having no env and only defaults data' do
        let(:file_path) { File.join(root, 'config/configuration.yml') }
        let(:env) { 'production' }

        it_behaves_like 'non-empty config file'

        it 'contains keys from defaults scope' do
          expect(subject[:default_dwarf]).to eq('default dwarf')
          expect(subject[:overriden_dwarf]).to eq('not yet overriden dwarf')
        end
      end

      context 'having only env and no default data' do
        let(:file_path) { File.join(root, 'config/no_defaults.yml') }

        context 'valid env' do
          let(:env) { 'production' }
          it_behaves_like 'non-empty config file'
        end

        context 'invalid env' do
          let(:env) { 'tropical' }
          it { expect(subject).to be_nil }
        end
      end
    end
  end
end
