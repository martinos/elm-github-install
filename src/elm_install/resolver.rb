require_relative './cache'
require_relative './utils'

module ElmInstall
  # Resolves git dependencies into the cache.
  class Resolver
    attr_reader :constraints

    # Initializes a resolver for a chace.
    def initialize(cache)
      @constraints = []
      @cache = cache
    end

    # Add constrains, usually from the `elm-package.json`.
    def add_constraints(constraints)
      @constraints = add_dependencies(constraints) do |package, constraint|
        [package, constraint]
      end
    end

    # Adds dependencies, usually from any `elm-package.json` file.
    #
    # :reek:NestedIterators { max_allowed_nesting: 2 }
    def add_dependencies(dependencies)
      dependencies.flat_map do |package_slug, constraint|
        package = Utils.transform_package(package_slug)

        add_package(package)

        Utils.transform_constraint(constraint).map do |dependency|
          yield package, dependency
        end
      end
    end

    # Adds a package to the cache, the following things happens:
    # * If there is no local repository it will be cloned
    # * Getting all the tags and adding the valid ones to the cache
    # * Checking out and getting the `elm-package.json` for each version
    #   and adding them recursivly
    def add_package(package)
      return if @cache.package?(package)

      puts "Package: #{package} not found in cache, cloning..."

      @cache
        .repository(package)
        .tags
        .map(&:name)
        .each do |version|
          @cache.ensure_version(package, version)
          add_version(package, version)
        end
    end

    # Adds a version and it's dependencies to the cache.
    def add_version(package, version)
      @cache
        .repository(package)
        .checkout(version)

      add_dependencies(elm_dependencies(package))
        .each do |dependent_package, constraint|
          add_package(key)
          @cache.dependency(package, version, [dependent_package, constraint])
        end
    end

    # Gets the `elm-package.json` for a package.
    def elm_dependencies(package)
      path = File.join(@cache.repository_path(package), 'elm-package.json')
      JSON.parse(File.read(path))['dependencies']
    rescue
      []
    end
  end
end