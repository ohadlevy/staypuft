module Staypuft
  class DeploymentStepsController < ApplicationController
    include Wicked::Wizard
    steps :deployment_settings, :services_selection, :services_configuration

    def show
      @layouts = Layout.all
      @deployment = Deployment.first

      render_wizard
    end

    def update
      # TODO(jtomasek): delete this info when Deployment model is done
      # we can use 'case' if we need to distinquish among steps
      # render_wizard @deployment will try to call save on that object
      # if validations fail, wizard renders submitted steps
      # in model we need to conditionally validate based on the step eg:
      # validates_presence_of :some_attribute, :if => :on_deployment_settings_step?
      # see wicked wiki for more info

      @layouts = Layout.all
      @deployment = Deployment.first

      case step
      when :deployment_settings
        @deployment.update_attributes(params[:staypuft_deployment])

        @deployment.hostgroup.name = @deployment.name
        @deployment.hostgroup.save!

        @deployment.layout.roles.each do |role|
          role_hostgroup = Hostgroup.where(:name =>"#{@deployment.name}: #{role.name}").first_or_initialize
          role_hostgroup.parent_id = @deployment.hostgroup.parent_id
          if !role.puppetclasses.empty? or role_hostgroup.puppetclasses.include?(role.puppetclasses.first)
            role_hostgroup.puppetclasses << role.puppetclasses.first
          end
          role_hostgroup.save!

          DeploymentRoleHostgroup.where(:deployment_id => @deployment.id, :hostgroup_id => role_hostgroup.id).first_or_create!
          HostgroupRole.where(:role_id => role.id, :hostgroup_id => role_hostgroup.id).first_or_create!
        end
      end

      render_wizard @deployment
    end

  private

    def redirect_to_finish_wizard(options = {})
      redirect_to deployments_path, :notice => "Deployment has been succesfully configured."
    end
  end
end