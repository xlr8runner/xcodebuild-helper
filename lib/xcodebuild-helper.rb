require 'xcode'
require 'execute'
require 'coverage_html_converter'
require 'fileutils'

module XCodeBuildHelper
  @registry = {}
  def self.[](name)
    @registry[name]
  end

  def self.gem_location
    File.expand_path(File.dirname(__dir__))
  end

  def self.define(name, &block)
    xcode = @registry[name]
    if xcode == nil
      xcode = XCodeBuildHelper::XCode.new
    end
    xcode.instance_eval(&block)
    @registry[name] = xcode
  end

  def self.build(name, device = nil)
    xcode = @registry[name]

    unless xcode == nil
      cmd = create_base_cmd(xcode)
      if device != nil
        cmd += parse_destination(xcode.get_device(device))
      end
      XCodeBuildHelper::Execute.call(cmd + "clean build | bundle exec xcpretty --color --report json-compilation-database")
    end
  end

  def self.test_suite(name, plan, device = nil)
    xcode = @registry[name]

    unless xcode == nil
      cmd = create_base_cmd(xcode)
      if device != nil
        cmd += parse_destination(xcode.get_device(device))
      end
      XCodeBuildHelper::Execute.call(cmd + "test | bundle exec xcpretty --color --report #{xcode.get_test_plan(plan).get_report_type}")
    end
  end

  def self.create_base_cmd(project)
    "xcodebuild -workspace \"#{project.get_workspace}.xcworkspace\" -scheme #{project.get_scheme} -sdk #{project.get_sdk} -config #{project.get_config} "
  end

  def self.parse_destination(device)
    if device == nil
      ""
    else
      "-destination 'platform=#{device.get_platform},name=#{device.get_name},OS=#{device.get_os}' "
    end
  end

  def self.base_app_location(xcode)
    unless xcode == nil
      cmd = create_base_cmd(xcode)
      result = XCodeBuildHelper::Execute.call(cmd + "-showBuildSettings")
      parse_app_settings(result)
    end
  end

  def self.parse_app_settings(settings)
    result = /OBJROOT = ([a-zA-Z0-9\/ _\-]+)/.match(settings)
    if result != nil
      result[1]
    else
      ""
    end
  end

  def self.app_binary_location(project)
    Dir.glob(base_app_location(project) + "/CodeCoverage/#{project.get_scheme}/Products/#{project.get_config}-#{project.get_sdk}/#{project.get_workspace.gsub(/\s+/, '\\ ')}.app/#{project.get_workspace.gsub(/\s+/,"\\ ")}").first
  end

  def self.get_binary(xcode)
    unless xcode == nil
        cmd = create_base_cmd(xcode)
        settings = XCodeBuildHelper::Execute.call(cmd + "-showBuildSettings")
        result = /TARGET_BUILD_DIR = ([a-zA-Z0-9\/ _\-]+)/.match(settings)
        if(result != nil)
          result[1] + "/#{xcode.get_workspace.gsub(/\s+/, '\\ ')}.app"
        else
          ""
        end
    end
  end

  def self.profdata_location(project)
    Dir.glob(base_app_location(project) + "/CodeCoverage/#{project.get_scheme}/Coverage.profdata").first
  end

  def self.generate_coverage(name, plan)
    xcode = @registry[name]
    unless xcode == nil
      coverage_plan = xcode.get_coverage_plan(plan)
      src_files = Dir.glob(coverage_plan.get_source_files.first).map{|file| file.gsub(/ /, "\\ ") }.join(' ')
      result = XCodeBuildHelper::Execute.call("xcrun llvm-cov show -instr-profile \"#{profdata_location(xcode)}\" \"#{app_binary_location(xcode)}\" #{src_files}")
      result = result.gsub(/^warning:.*\n/, '')
      all_results = []
      result.split("\n\n").each do |file|
        converted_result = XCodeBuildHelper::CoverageHtmlConverter.convert_file file
        all_results << converted_result
        if converted_result
          FileUtils::mkdir_p coverage_plan.get_output
          basename = File.basename(converted_result[:title])
          File.write(File.join(coverage_plan.get_output, basename + '.html'), converted_result[:content].to_html)
        end
      end

      unless all_results.empty?
        index_file = XCodeBuildHelper::CoverageHtmlConverter.create_index all_results
        File.write(File.join(coverage_plan.get_output, 'index.html'), index_file.to_html)
      end

      FileUtils::cp(File.join(gem_location, 'assets/style.css'), coverage_plan.get_output)
    end
  end

  def self.lint(name, plan)
    xcode = @registry[name]
    lint_plan = xcode.get_lint_plan(plan)

    cmd = "bundle exec oclint-json-compilation-database"
    if(lint_plan.get_ignore)
      cmd += " -e \"#{lint_plan.get_ignore}\""
    end
    cmd += " --"
    if(lint_plan.get_report_type && lint_plan.get_output)
      cmd += " -report-type #{lint_plan.get_report_type} -o #{lint_plan.get_output}"
    end

    rules = lint_plan.get_rules
    rules.get_attribute_list.each do |key|
      u_key = rules.send("key_" + key.to_s)
      value = rules.send("get_" + key.to_s)
      cmd += " -rc #{u_key}=#{value}"
    end

    XCodeBuildHelper::Execute.call(cmd)
  end

  def self.launch(name, device)
    xcode = @registry[name]

    unless xcode == nil
      device = xcode.get_device(device)
      log_location = "./simulator-debug.log"
      XCodeBuildHelper::Execute.call("bundle exec ios-sim launch \"#{get_binary(xcode)}\" --devicetypeid \"#{device.get_name.gsub(/\s+/, '-')}, #{device.get_os}\" --log #{log_location}")
    end
  end
end
