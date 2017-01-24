#-- copyright
# OpenProject is a project management system.
# Copyright (C) 2012-2017 the OpenProject Foundation (OPF)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License version 3.
#
# OpenProject is a fork of ChiliProject, which is a fork of Redmine. The copyright follows:
# Copyright (C) 2006-2017 Jean-Philippe Lang
# Copyright (C) 2010-2013 the ChiliProject Team
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.
#
# See doc/COPYRIGHT.rdoc for more details.
#++

module API
  module V3
    class WorkPackageCollectionFromQueryService
      include Utilities::PathHelper

      def initialize(query, user)
        self.query = query
        self.current_user = user
      end

      def call(params = {})
        self.overriding_params = params
        self.default_params = calculate_default_params

        update = UpdateQueryFromV3ParamsService
                 .new(query, current_user)
                 .call(params)

        if update.success?
          representer = results_to_representer

          ServiceResult.new(success: true, result: representer)
        else
          update
        end
      end

      private

      def results_to_representer
        collection_representer(query.results.sorted_work_packages,
                               project: query.project,
                               groups: generate_groups,
                               sums: generate_total_sums)
      end

      attr_accessor :query,
                    :current_user,
                    :overriding_params,
                    :default_params

      def representer
        ::API::V3::WorkPackages::WorkPackageCollectionRepresenter
      end

      def merged_params
        # #merge will not work because 'page' and :page are different keys
        default_params.each_with_object({}) do |(k, v), h|
          h[k] = overriding_params[k] || v
        end
      end

      def calculate_default_params
        ::API::V3::Queries::QueryParamsRepresenter
          .new(query)
          .to_h
      end

      def generate_groups
        return unless merged_params[:groupBy]

        results = query.results

        results.work_package_count_by_group.map do |group, count|
          sums = if merged_params[:showSums] == 'true'
                   format_query_sums results.all_sums_for_group(group)
                 end

          ::API::Decorators::AggregationGroup.new(group, count, sums: sums)
        end
      end

      def generate_total_sums
        return unless merged_params[:showSums] == 'true'

        format_query_sums query.results.all_total_sums
      end

      def format_query_sums(sums)
        OpenStruct.new(format_column_keys(sums))
      end

      def format_column_keys(hash_by_column)
        ::Hash[
          hash_by_column.map do |column, value|
            match = /cf_(\d+)/.match(column.name.to_s)

            column_name = if match
                            "custom_field_#{match[1]}"
                          else
                            column.name.to_s
                          end

            [column_name, value]
          end
        ]
      end

      def collection_representer(work_packages, project:, groups:, sums:)
        ::API::V3::WorkPackages::WorkPackageCollectionRepresenter.new(
          work_packages,
          self_link(project),
          project: project,
          query: merged_params,
          page: to_i_or_nil(merged_params[:offset]),
          per_page: to_i_or_nil(merged_params[:pageSize]),
          groups: groups,
          total_sums: sums,
          embed_schemas: true,
          current_user: current_user
        )
      end

      def to_i_or_nil(value)
        value ? value.to_i : nil
      end

      def self_link(project)
        if project
          api_v3_paths.work_packages_by_project(project.id)
        else
          api_v3_paths.work_packages
        end
      end

      def convert_to_v3(attribute)
        ::API::Utilities::PropertyNameConverter.from_ar_name(attribute).to_sym
      end
    end
  end
end
