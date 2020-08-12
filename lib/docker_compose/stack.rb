# Represents the stack we wish to build as configued from the stack.yml file
module DockerCompose
  class Stack
    REQUIRED_SERVICES = 'setup'.freeze

    def initialize(stack, using:)
      @architecture = using
      @stack = stack.with_indifferent_access
      @data = { version: architecture.version }.with_indifferent_access
    end

    def enabled_services
      list = @stack[:enabled].map { |name| resolve_group(name) }.flatten
      list.prepend(*REQUIRED_SERVICES)
      list.uniq
    end

    def resolve_group(name)
      if @stack[:groups].key?(name)
        @stack[:groups][name].map(&method(:resolve_group))
      else
        [name, resolve_dependencies(name)]
      end
    end

    def resolve_dependencies(name)
      @architecture.services[name].dependencies
    end

    def configuration_for(name)
      @stack[:configure][name] || {}
    end

    def add_service(name)
      service = @architecture.services[name]
      service.override(configuration_for(name))

      @data[:services][name] = service.data
    end

    def prepare
      @data["services"] = {}
      enabled_services.map(&method(:add_service))
    end

    def write_docker_compose
      prepare

      puts "Writing new docker-compose.yml with #{@data[:services].length} services."
      File.open("docker-compose.yml", "w") { |f| f.write @data.to_hash.to_yaml }
    end

    private
    attr_reader :architecture, :stack, :data
  end
end