# Copyright 2017 Google Inc.
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

module Provider
  module Ansible
    # Responsible for building out the AnsibleModule code.
    # AnsibleModule is responsible for input validation.
    module Module
      # Returns the Python dictionary representing a simple property for
      # validation.
      def python_dict_for_property(prop, object, spaces = 0)
        return if prop.crud.eql?("r")
        if prop.is_a?(Api::Type::Array) && \
           prop.item_type.is_a?(Api::Type::NestedObject)
          nested_obj_dict(prop, object, order_properties(prop.item_type.properties), spaces)
        elsif prop.is_a? Api::Type::NestedObject
          nested_obj_dict(prop, object, order_properties(prop.properties), spaces)
        else
          name = Google::StringUtils.underscore(prop.out_name)
          indent("#{name}=dict(#{prop_options(prop, object, spaces).join(', ')})", spaces)
        end
      end

      private

      # Creates a Python dictionary representing a nested object property
      # for validation.
      def nested_obj_dict(prop, object, properties, spaces)
        name = Google::StringUtils.underscore(prop.out_name)
        options = prop_options(prop, object, spaces).join(', ')
        h = indent("#{name}=dict(#{options}, options=dict(", spaces)
        t = indent('))', spaces)
        if h.length > 79
          h = indent([
            "#{name}=dict(",
            indent("#{options},\noptions=dict(", 4)
          ], spaces)
          t = indent("    ),\n)", spaces)
          spaces += 4
        end
        [
          h,
          indent_list((properties.map do |p|
            python_dict_for_property(p, object, spaces + 4)
          end).compact, 0),
          t
        ].flatten
      end

      # Returns an array of all base options for a given property.
      def prop_options(prop, _object, spaces)
        default = ""
        if prop.default
          default = prop.default
          if prop.is_a?(Api::Type::String) || prop.is_a?(Api::Type::Time) || prop.is_a?(Api::Type::Enum)
            default = sprintf("\'%s\'", default)
          end
        end
        [
          "type=#{quote_string(python_type(prop))}",
          ('required=True' if prop.required),
          (choices_enum(prop, spaces) if prop.is_a? Api::Type::Enum),
          ('default=' + default if prop.default),
          ("elements=#{quote_string(python_type(prop.item_type))}" \
            if prop.is_a? Api::Type::Array),
          ("aliases=[#{prop.aliases.map { |x| quote_string(x) }.join(', ')}]" \
            if prop.aliases)
        ].compact
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength

      # Returns a formatted string represented the choices of an enum
      # rubocop:disable Metrics/AbcSize
      # rubocop:disable Metrics/MethodLength
      def choices_enum(prop, spaces)
        name = Google::StringUtils.underscore(prop.out_name)
        t = python_type(prop)
        type = "type=#{quote_string(t)}"
        # + 6 for =dict(
        choices_indent = spaces + name.length + type.length + 6
        if t == 'str'
          format([
                   [
                     "choices=[#{prop.values.map do |x|
                                   quote_string(x.to_s)
                                 end.join(', ')}]"
                   ],
                   [
                     "choices=['#{prop.values[0]}',",
                     prop.values[1..-2].map do |x|
                       "#{indent(quote_string(x.to_s), choices_indent + 11)},"
                     end,
                     # + 11 for ' choices='
                     indent("#{quote_string(prop.values[-1].to_s)}]",
                            choices_indent + 11)
                   ]
                 ], 0, choices_indent)
        else
          format([
                   [
                     "choices=[#{prop.values.map do |x|
                                   x.to_s
                                 end.join(', ')}]"
                   ],
                   [
                     "choices=[#{prop.values[0].to_s},",
                     prop.values[1..-2].map do |x|
                       "#{indent(x.to_s, choices_indent + 11)},"
                     end,
                     # + 11 for ' choices='
                     indent("#{prop.values[-1].to_s}]",
                            choices_indent + 11)
                   ]
                 ], 0, choices_indent)
        end
      end
      # rubocop:enable Metrics/AbcSize
      # rubocop:enable Metrics/MethodLength
    end
  end
end
