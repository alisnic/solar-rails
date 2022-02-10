module Solargraph
  module Arc
    class Devise
      def self.instance
        @instance ||= self.new
      end

      def process(source_map, ns)
        if source_map.filename.include?("app/models")
          process_model(source_map.source, ns)
        else
          []
        end
      end

      private

      def process_model(source, ns)
        walker = Walker.from_source(source)
        pins   = []

        walker.on :send, [nil, :devise] do |ast|
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
        Solargraph.logger.debug("[ARC][Devise] added #{pins.map(&:name)} to #{ns.path}") if pins.any?
        pins
      end
    end
  end
end
