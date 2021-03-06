require 'amitree/git_client'
require 'amitree/heroku_client'
require 'amitree/utils'
require 'pivotal-tracker'

module Amitree
  class HerokuDeployer
    class ReleaseDetails
      attr_accessor :production_release, :staging_release_to_deploy, :stories, :git_range

      def initialize
        @stories = []
      end

      class Story < DelegateClass(PivotalTracker::Story)
        attr_accessor :deliverable
        attr_reader :blocked_by

        def initialize(tracker_story)
          super(tracker_story)
          @deliverable = false
          @blocked_by = []
        end

        def blocked_by=(blocked_by)
          @blocked_by = blocked_by
          if @blocked_by.length > 0
            @deliverable = false
          else
            @deliverable = true
          end
        end
      end
    end

    def initialize(options={})
      @heroku = options[:heroku] || Amitree::HerokuClient.new(options[:heroku_api_key], options[:heroku_staging_app], options[:heroku_production_app])
      @git = options[:git] || Amitree::GitClient.new(options[:github_repo], options[:github_username], options[:github_password], verbose: options[:verbose])
      PivotalTracker::Client.token = options[:tracker_token]
      PivotalTracker::Client.use_ssl = true
      @tracker_projects = PivotalTracker::Project.all
      @tracker_cache = {}
    end

    def compute_release(options={})
      result = ReleaseDetails.new

      result.production_release = @heroku.last_promoted_production_release
      staging_releases = @heroku.staging_releases_since(result.production_release)

      prod_commit = @heroku.get_production_commit(result.production_release)
      puts "Production release is #{prod_commit}" if options[:verbose]

      git_range = @git.range_since(prod_commit)
      result.stories = all_stories(git_range)
      all_stories = Hash[result.stories.map{|story| [story.id, story]}]

      staging_releases.reverse.each do |staging_release|
        begin
          staging_commit = @heroku.get_staging_commit(staging_release)

          puts "- Trying staging release #{@heroku.version(staging_release)} with commit #{staging_commit}" if options[:verbose]

          candidate_git_range = git_range.up_to(staging_commit)
          stories = all_stories.values_at(*candidate_git_range.story_ids).compact
          story_ids = stories.map(&:id)

          puts "  - Stories: #{story_ids.inspect}" if options[:verbose]

          unaccepted_story_ids = story_ids.select { |story_id| get_tracker_status(story_id) != 'accepted' }

          if unaccepted_story_ids.length > 0
            stories.each do |story|
              story.blocked_by = unaccepted_story_ids
            end
            puts "    - Some stories are not yet accepted: #{unaccepted_story_ids.inspect}" if options[:verbose]
          elsif story_ids.length == 0 && !options[:allow_empty]
            puts "    - Refusing to deploy empty release" if options[:verbose]
          else
            story_ids_referenced_later = story_ids & git_range.since(staging_commit).story_ids
            if story_ids_referenced_later.length > 0
              puts "    - Some stories have been worked on in a later commit: #{story_ids_referenced_later}" if options[:verbose]
            else
              stories.each do |story|
                story.blocked_by = unaccepted_story_ids
              end
              puts "    - This release is good to go!" if options[:verbose]
              result.staging_release_to_deploy = staging_release
              result.git_range = candidate_git_range
              break
            end
          end
        rescue => error
          puts "  - Skipping candidate staging release because an error was encountered"
          puts "\n#{error.class} (#{error.message}):\n  " + error.backtrace.join("\n  ") + "\n"
        end
      end

      return result
    end

    def get_tracker_status(story_id)
      tracker_data(story_id).current_state
    end

    def tracker_data(story_id)
      @tracker_cache[story_id] ||= @tracker_projects.map_detect do |project|
        project.stories.find(story_id)
      end
    end

    def all_stories(git_range)
      git_range.story_ids.map do |story_id|
        if story = tracker_data(story_id)
          ReleaseDetails::Story.new(story)
        end
      end.compact
    end

    def tracker_project(project_id)
      @tracker_projects.detect{|project| project.id == project_id.to_i} or raise "Unknown project id: #{project_id}"
    end
  end
end
