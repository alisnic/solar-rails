module SolarRails
  class Devise
    def self.instance
      @instance ||= self.new
    end

    def initialize
      @seen_devise_closures = []
    end

    def process(source_map, ns)
      if source_map.filename.include?("app/models")
        process_model(source_map, ns)
      elsif source_map.filename.end_with?("app/controllers/application_controller.rb")
        process_controller(source_map, ns)
      else
        []
      end
    end

    private

    def process_model(source_map, ns)
      ast    = source_map.source.node
      walker = Walker.new(ast)
      pins   = []

      walker.on :send, [nil, :devise] do |ast|
        @seen_devise_closures << ns

        modules = ast.children[2..-1]
          .map {|c| c.children.first }
          .select {|s| s.is_a?(Symbol) }

        modules.each do |mod|
          pins << Util.build_module_include(
            ns,
            "Devise::Models::#{mod.to_s.capitalize}",
            Util.build_location(ast, ns.filename)
          )
        end
      end

      walker.walk
      pins
    end

    def process_controller(source_map, ns)
      pins = [
        Util.build_module_include(
          ns,
          "Devise::Controllers::Helpers",
          Util.dummy_location(ns.filename)
        )
      ]

      pins + @seen_devise_closures.map do |model_ns|
        Util.build_public_method(
          ns,
          "current_#{model_ns.name.downcase}",
          types: [model_ns.name, "nil"],
          ast:   source_map.source.node,
          path:  ns.filename
        )
      end
    end
  end
end