# require "chef/knife/job_helpers"
require "./job_helpers"

class Chef
  class Knife
    class JobSplay < Chef::Knife

      include JobHelpers

      deps do
        require "chef/rest"
        require "chef/node"
        require "chef/search/query"
      end

      banner "knife job splay <command> [<node> <node> ...]"

      option :quorum,
             :short => "-q QUORUM",
             :long => "--quorum QUORUM",
             :default => "100%",
             :description => "Pushy job quorum. Percentage (-q 50%) or Count (-q 145)."

      option :search,
             :short => "-s QUERY",
             :long => "--search QUERY",
             :required => false,
             :description => "Solr query for list of job candidates."
 
      option :poll_interval,
             :long => "--poll-interval RATE",
             :default => 1.0,
             :description => "Repeat interval for job status update (in seconds)."

      option :run_timeout,
             :long => "--timeout TIMEOUT",
             :description => "Maximum time the job will be allowed to run (in seconds)."

      option :interval,
             :long => "--interval",
             :default => 2.0,
             :description => "The frequency (in seconds) at which jobs are started for each node"

      def run
        job_name = @name_args[0]
        if job_name.nil?
          ui.error "No job specified."
          show_usage
          exit 1
        end

        @node_names = process_search(config[:search], name_args[1, @name_args.length - 1])

        job_json = {"command" => job_name}
        job_json["quorum"] = get_quorum(config[:quorum], @node_names.length)

        job_uris = []
        @node_names.each do |node_name|
          job_json[:nodes] = [node_name]
          job_uris.push(run_starter(config, job_json))
          puts "Started #{node_name}: #{job_id_from_uri(job_uris.last)}"
          sleep(config[:interval].to_f) if not node_name == @node_names.last
        end

        jobs = []
        job_uris.each do |job_uri|
          jobs.push(get_completed_job(config, job_uri))
        end

        jobs.each{ |job| output(job) }

        status = jobs.max_by{ |job| status_code(job) }
        return status
      end

      private

    end
  end
end
