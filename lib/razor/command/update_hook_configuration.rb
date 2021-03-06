# -*- encoding: utf-8 -*-

class Razor::Command::UpdateHookConfiguration < Razor::Command
  summary "Update one key in a hook's configuration"
  description <<-EOT
This allows for updating, adding, and removing a single key of a hook's
configuration.
  EOT

  example api: <<-EOT
Set a single key from a node:

    {"node": "node1", "key": "my_key", "value": "twelve"}
  EOT

  example cli: <<-EOT
Set a single key from a node:

    razor update-hook-configuration --node node1 \\
        --key my_key --value twelve
  EOT

  authz '%{hook}'

  attr 'hook', type: String, required: true, references: [Razor::Data::Hook, :name],
               help: _('The hook for which to update configuration.')

  attr 'key', required: true, type: String, size: 1..Float::INFINITY,
              help: _('The key to change in the configuration.')

  attr 'value', help: _('The value for the configuration.')

  attr 'clear', type: TrueClass,
                     help: _(<<-EOT)
If true, the key will be either reset back to its default or
removed from the configuration, depending on whether a default exists.
EOT

  require_one_of 'value', 'clear'

  # Update/add specific configuration key
  def run(request, data)
    hook = Razor::Data::Hook[:name => data['hook']]
    config = hook.configuration
    result = if data['value']
               config[data['key']] = data['value']
               _("value for key %{name} updated") %
                   {name: data['key']}
             elsif data['clear'] and config.has_key?(data['key'])
               config.delete(data['key'])
               attr_schema = hook.hook_type.configuration_schema[data['key']]
               if attr_schema and attr_schema['default']
                 # The actual setting happens as part of the validation.
                 _("value for key %{name} reset to default") %
                     {name: data['key']}
               else
                 _("key %{name} removed from configuration") %
                     {name: data['key']}
               end
             else
               _("no changes; key %{name} already absent") %
                     {name: data['key']}
             end
    hook.configuration = config
    begin
      hook.save
      { :result => result }
    rescue Sequel::ValidationFailed => _
      request.error 422, :error => _("cannot clear required configuration key #{data['key']}")
    end
  end
end
