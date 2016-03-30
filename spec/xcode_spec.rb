require 'xcode'

RSpec.describe XCodeBuildHelper::XCode do
  before(:each) do
    @xcode = XCodeBuildHelper::XCode.new "WORK SPACE", "SCHEME"
  end

  context "Initializer" do
    it "sets workspace in the constructor" do
      expect(@xcode.workspace).to eq "WORK SPACE"
    end

    it "sets scheme in the constructor" do
      expect(@xcode.scheme).to eq "SCHEME"
    end
  end

  context "#build" do
    it "will call xcodebuild with proper parameters" do
      expect(XCodeBuildHelper::Execute).to receive(:call).with("xcodebuild -workspace \"WORK SPACE.xcworkspace\" -scheme SCHEME -sdk iphonesimulator -config Debug clean build | bundle exec xcpretty --report json-compilation-database")
      @xcode.build
    end

    it "will call with optional destination parameters" do
      expect(XCodeBuildHelper::Execute).to receive(:call).with("xcodebuild -workspace \"WORK SPACE.xcworkspace\" -scheme SCHEME -sdk iphonesimulator -config Debug -destination 'platform=PLATFORM,name=NAME,OS=myOS' clean build | bundle exec xcpretty --report json-compilation-database")
      @xcode.build :platform => 'PLATFORM', :name => 'NAME', :os => 'myOS'
    end
  end

  context "#test_suite" do
    it "will call the correct text configuration" do
      expect(XCodeBuildHelper::Execute).to receive(:call).with("xcodebuild -workspace \"WORK SPACE.xcworkspace\" -scheme SCHEME -sdk iphonesimulator -config Debug test | bundle exec xcpretty --color --report html")
      @xcode.test_suite
    end

    it "will call with optional destination parameters" do
      expect(XCodeBuildHelper::Execute).to receive(:call).with("xcodebuild -workspace \"WORK SPACE.xcworkspace\" -scheme SCHEME -sdk iphonesimulator -config Debug -destination 'platform=PLATFORM,name=NAME,OS=myOS' test | bundle exec xcpretty --color --report html")
      @xcode.test_suite :platform => 'PLATFORM', :name => 'NAME', :os => 'myOS'
    end
  end

  context "#coverage" do
    it "will generate the code coverage for the sources provided" do
      allow(@xcode).to receive(:app_binary_location).and_return('/path/to/app/binary')
      allow(@xcode).to receive(:profdata_location).and_return('/path/to/profdata')
      expect(XCodeBuildHelper::Execute).to receive(:call).with("xcrun llvm-cov show -instr-profile \"/path/to/profdata\" \"/path/to/app/binary\" \"/my/source/files\"")
      @xcode.generate_coverage "/my/source/files"
    end
  end

  context "#base_app_location" do
    it "will get the app options" do
      expect(XCodeBuildHelper::Execute).to receive(:call).with("xcodebuild -workspace \"WORK SPACE.xcworkspace\" -scheme SCHEME -sdk iphonesimulator -config Debug -showBuildSettings")
      @xcode.base_app_location
    end

    it "will return the path" do
      allow(XCodeBuildHelper::Execute).to receive(:call).and_return("OPTION_A = something \nOBJROOT = /path/to/app\nOPTION_B = something else")
      expect(@xcode.base_app_location).to eq '/path/to/app'
    end
  end

	# coverage_directory = Dir[File.join(app_directory.strip, '/CodeCoverage/ServiceLogistics')].first
	# puts `xcrun llvm-cov show -instr-profile #{coverage_directory}/Coverage.profdata "#{coverage_directory}/Products/Debug-iphonesimulator/Service Logistics.app/Service Logistics" DSL462_iOS/**/*.m`
  context "#app_binary_location" do
    it "will return the location of the app executable" do
      allow(XCodeBuildHelper::Execute).to receive(:call).and_return("OPTION_A = something \nOBJROOT = /path/to/app\nOPTION_B = something else")
      allow(Dir).to receive(:glob).and_return(['/path/to/app/binary.app'])
      expect(@xcode.app_binary_location).to eq '/path/to/app/binary.app'
    end

    it "will search for the binary location" do
      allow(XCodeBuildHelper::Execute).to receive(:call).and_return("OPTION_A = something \nOBJROOT = /path/to/app\nOPTION_B = something else")
      expect(Dir).to receive(:glob).with("/path/to/app/CodeCoverage/SCHEME/Products/Debug-iphonesimulator/WORK\\ SPACE.app/WORK\\ SPACE").and_return([])
      @xcode.app_binary_location
    end
  end

  context "#profdata_location" do
    it "will return the location of the profdata" do
      allow(XCodeBuildHelper::Execute).to receive(:call).and_return("OPTION_A = something \nOBJROOT = /path/to/app\nOPTION_B = something else")
      expect(Dir).to receive(:glob).with("/path/to/app/CodeCoverage/SCHEME/Coverage.profdata")
      @xcode.profdata_location
    end
  end
end
