module Solargraph
  module Arc
    class Model
      def self.instance
        @instance ||= self.new
      end

      def process(source_map, ns)
        return [] unless source_map.filename.include?("app/models")

        walker = Walker.from_source(source_map.source)
        pins   = []

        walker.on :send, [nil, :belongs_to] do |ast|
          pins << singular_association(ns, ast)
        end

        walker.on :send, [nil, :has_one] do |ast|
          pins << singular_association(ns, ast)
        end

        walker.on :send, [nil, :has_many] do |ast|
          pins << plural_association(ns, ast)
        end

        walker.on :send, [nil, :has_and_belongs_to_many] do |ast|
          pins << plural_association(ns, ast)
        end

        walker.on :send, [nil, :scope] do |ast|
          name = ast.children[2].children.last

          pins << Util.build_public_method(
            ns,
            name.to_s,
            types: ns.return_type.map(&:tag),
            scope: :class,
            location: Util.build_location(ast, ns.filename)
          )
        end

        walker.walk
        Solargraph.logger.debug("[ARC][Model] added #{pins.map(&:name)} to #{ns.path}") if pins.any?
        pins
      end

      def plural_association(ns, ast)
        relation_name = ast.children[2].children.first
        class_name = extract_custom_class_name(ast) || relation_name.to_s.singularize.camelize

        Util.build_public_method(
          ns,
          relation_name.to_s,
          types: ["ActiveRecord::Associations::CollectionProxy<#{class_name}>"],
          location: Util.build_location(ast, ns.filename)
        )
      end

      def singular_association(ns, ast)
        relation_name = ast.children[2].children.first
        class_name = extract_custom_class_name(ast) || relation_name.to_s.camelize

        Util.build_public_method(
          ns,
          relation_name.to_s,
          types: [class_name],
          location: Util.build_location(ast, ns.filename)
        )
      end

      def extract_custom_class_name(ast)
        options = ast.children[3..-1].find { |n| n.type == :hash }
        return unless options

        class_name_pair = options.children.find do |n|
          n.children[0].deconstruct == [:sym, :class_name] && n.children[1].type == :str
        end
        class_name_pair && class_name_pair.children.last.children.last
      end
    end
  end
end
