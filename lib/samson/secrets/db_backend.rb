# frozen_string_literal: true
module Samson
  module Secrets
    class DbBackend
      class Secret < ActiveRecord::Base
        include AttrEncryptedSupport

        self.table_name = :secrets
        self.primary_key = :id # uses a string id

        attribute :value
        attr_encrypted :value

        validates :id, :encrypted_value, :encryption_key_sha, presence: true
        validates :id, format: %r{\A([^/\s]+/){3}[^\s]+\Z}
      end

      class << self
        def read(id)
          return unless secret = Secret.find_by_id(id)
          secret_to_hash secret
        end

        def read_multi(ids)
          secrets = Secret.where(id: ids).all
          secrets.each_with_object({}) { |s, a| a[s.id] = secret_to_hash(s) }
        end

        def write(id, data)
          secret = Secret.where(id: id).first_or_initialize
          secret.value = data.fetch(:value)
          secret.visible = data.fetch(:visible)
          secret.comment = data.fetch(:comment)
          secret.updater_id = data.fetch(:user_id)
          secret.creator_id ||= data.fetch(:user_id)
          secret.save
        end

        def delete(id)
          Secret.delete(id)
        end

        def ids
          Secret.order(:id).pluck(:id)
        end

        def filter_ids_by_value(ids, value)
          ids.each_slice(1000).flat_map do |group|
            Secret.where(id: group).select { |s| Rack::Utils.secure_compare(s.value, value) }.map(&:id)
          end
        end

        def deploy_groups
          DeployGroup.all
        end

        private

        def secret_to_hash(secret)
          {
            value: secret.value,
            visible: secret.visible,
            comment: secret.comment,
            updater_id: secret.updater_id,
            creator_id: secret.creator_id,
            updated_at: secret.updated_at,
            created_at: secret.created_at
          }
        end
      end
    end
  end
end
