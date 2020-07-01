# Encoding: utf-8
# IBM WebSphere Application Server Liberty Buildpack
# Copyright 2017 the original author or authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'liberty_buildpack/diagnostics/logger_factory'
require 'liberty_buildpack/framework'
require 'liberty_buildpack/repository/configured_item'
require 'liberty_buildpack/util/download'
require 'liberty_buildpack/container/common_paths'
require 'liberty_buildpack/services/vcap_services'
require 'fileutils'
require 'rexml/document'

module LibertyBuildpack::Framework

  #------------------------------------------------------------------------------------
  # The WaratekAgent class that provides Waratek Agent resources as a framework to applications
  #------------------------------------------------------------------------------------
  class WaratekAgent

    #-----------------------------------------------------------------------------------------
    # Creates an instance, passing in a context of information available to the component
    #
    # @param [Hash] context the context that is provided to the instance
    # @option context [String] :app_dir the directory that the application exists in
    # @option context [Hash] :configuration the properties provided by the user
    # @option context [CommonPaths] :common_paths the set of paths common across components that components should reference`
    # @option context [Hash] :vcap_services the services bound to the application provided by cf
    # @option context [Array<String>] :java_opts an array that Java options can be added to
    #-----------------------------------------------------------------------------------------
    def initialize(context = {})
      @logger = LibertyBuildpack::Diagnostics::LoggerFactory.get_logger
      @app_dir = context[:app_dir]
      @configuration = context[:configuration]
      @common_paths = context[:common_paths] || LibertyBuildpack::Container::CommonPaths.new
      @java_opts = context[:java_opts]
      @environment = context[:environment]
    end

    #-----------------------------------------------------------------------------------------
    # Determines if the application requires Waratek.
    #
    # @return [String] the detected versioned ID if the environment and config are valid, otherwise nil
    #------------------------------------------------------------------------------------------
    def detect
      waratek_required? ? process_config : nil
    end

    #-----------------------------------------------------------------------------------------
    # Create the waratek directory and its contents for the app droplet.
    #------------------------------------------------------------------------------------------
    def compile
      if @app_dir.nil?
        raise 'app directory must be provided' if @app_dir.nil?
      elsif @uri.nil?
        raise "uri #{@uri} is not available, detect needs to be invoked"
      end

      # create a waratek home dir in the droplet
      waratek_home = File.join(@app_dir, WARATEK_DIR)
      FileUtils.mkdir_p(waratek_home)
      # Download the Agent
      download_agent(@version, @uri, waratek_home)
    end

    #-----------------------------------------------------------------------------------------
    # Processes the configuration to obtain the corresponding version and uri of the
    # Waratek Agent jar in the repository root. If the configuration can be processed and the
    # uri contains a valid Waratek Agent jar name, the versioned ID is returned and configuration
    # data is initialized. this has yet to be implemented
    # 
    # Currently, this just gets the URI as specified in the config yaml file. It's structured for
    # future use, returning a hardcoded version in the correct format.
    #
    # @return [String] the Waratek version ID
    #------------------------------------------------------------------------------------------
    def process_config
      @uri = @configuration['uri']
      @version = @configuration['version']
      
      # Thae Agent doesn't yet specify the URI or the Repository Root. At present, it's
      # the application that defines the location of the Agent zip file to download
      if @uri.nil?
        @uri = @environment['waratek_treasure']
      end
      
      @version.nil? ? nil : version_identifier
    end

    #-----------------------------------------------------------------------------------------
    # Create the Waratek Agent options appended as java_opts.
    #------------------------------------------------------------------------------------------
    def release
      # Don't put any print or puts statements in here as they'll block staging causing
      # errors - not sure why.
      
      # Waratek paths within the droplet
      app_dir = @common_paths.relative_location
      waratek_home_dir = File.join(app_dir, WARATEK_DIR)
      # Set up the jaavagent parameter
      waratek_agent = File.join(waratek_home_dir, WARATEK_JAR)
      @java_opts << "-javaagent:#{waratek_agent}"
      # Set up the agentpath parameter
      #waratek_lib = File.join(waratek_home_dir, WARATEK_LIB)
      #@java_opts << "-agentpath:#{waratek_lib}"
      # Set up container home - the guest JDK
      java_home = File.join(app_dir, DEFAULT_JAVA)
      @java_opts << "-Dcom.waratek.ContainerHome=#{java_home}"
      
      # Has the application manifest provided a 'waratek.properties' file?
      if waratek_properties_supplied?
        # 'waratek-properties' is a location of the rules file relative to the app directory
        waratek_props_file = File.join(app_dir, @environment['waratek_properties'])
        @java_opts << "-Dcom.waratek.WaratekProperties=#{waratek_props_file}"
      end
      # If the application hasn't provided a 'waratek.properties' file, we'll refer
      # to what is supplied in the download zip, in 'waratek.properties'.
      # Currently, it uses supplied 'bluemis.rules' and write log output
      # to 'bluemix_rules.log' but we may modify to use the BlueMix logging feature in future
    end  

    private

    # Name of Waratek Agent jar in the download
    WARATEK_JAR = 'waratek.jar'.freeze
    # Name of the Waratek library in the download
    #WARATEK_LIB = 'libwaratek.so'.freeze
    # Subdirectory under the app directory into which we place the download and unpack
    WARATEK_DIR = '.waratek'.freeze
    # Default location of Java
    DEFAULT_JAVA = '.java'.freeze

    def zip_name
      "#{version_identifier}.zip"
    end

    def version_identifier
      "waratek-secure-19.0.0"
    end

    #-----------------------------------------------------------------------------------------
    #
    # @return [Boolean]  true if the app is requesting Waratek by setting an env variable.
    # Will need to expand this to use services as per other agents.
    #------------------------------------------------------------------------------------------
    def waratek_required?
      @environment['waratek_required'] && @configuration['enabled']
    end

    #-----------------------------------------------------------------------------------------
    # 
    # @return [Boolean] if the value of the env variable 'waratek_properties' is set by the app, otherwise nil
    # 
    #-----------------------------------------------------------------------------------------
    def waratek_properties_supplied?
      @environment['waratek_properties']
    end
    
    #-----------------------------------------------------------------------------------------
    # Download the agent library from the uri as specified in the waratek configuration.
    #------------------------------------------------------------------------------------------
    def download_agent(version_desc, uri_source, target_dir)
      download_start_time = Time.now
      LibertyBuildpack::Util.download_zip(version_desc, uri_source, 'Waratek Agent', target_dir)
    rescue => e
      raise "Unable to download the Waratek Agent zip. Ensure that the agent zip at #{uri_source} is available and accessible. #{e.message}"
    end

  

  end
end
