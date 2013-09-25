require 'bundler'
Bundler.require

require 'json'

CONFIG = YAML.load_file("./config/config.yml")
JIRA_URI = CONFIG.fetch("jira_uri")

#FRECKLE_URI = CONFIG.fetch("freckle_uri")
#FRECKLE_TOKEN = ENV['FRECKLE_TOKEN'] || CONFIG.fetch("freckle_token")

class HarvestEntriesFetcher
  def self.on(date)
    new.on(date)
  end

  def on(date)
    harvest.time.all(date).map do |entry|
      HarvestToFeckcleAdapter.new(entry)
    end
  end

  def harvest
    subdomain = '21croissants'
    username = CONFIG.fetch "harvest_username"
    password = CONFIG.fetch "harvest_password"

    @harvest ||= Harvest.hardy_client(subdomain, username, password)
  end
end

class HarvestToFeckcleAdapter
  def initialize(entry)
    @entry = entry
  end

  def date
    @entry.spent_at
  end

  def minutes
    @entry.hours * 60
  end

  def project_id
    @entry.project_id
  end

  def activity_name
    case @entry.task_id
    when "1990250"
      :dev
    when "1990251"
      :meeting
    when "2171705"
      :training
    else
      raise "activity name not found"
    end
  end

  def comment
    @entry.notes
  end

  def description
    @entry.notes
  end

end

class ProjectMapping
  def self.call(freckle_project_id)
    MAPPING[freckle_project_id.to_i]
  end

  MAPPING = YAML.load_file "./config/freckle_project_to_jira_project.yml"
end

# https://verdacom.atlassian.net/browse/VCORE-1805?jql=labels%20%3D%20Tempo
class TicketMapping
  # @return [String] ticket id for project + activity
  def self.call(project_id, activity_id)
    MAPPING.fetch(project_id.to_s).fetch(activity_id.to_s)
  rescue KeyError
    raise KeyError, "Activity not found: #{project_id} / #{activity_id}"
  end

  MAPPING = YAML.load_file "./config/activity_to_jira_issue.yml"
end


JIRA_USERNAME = ENV['JIRA_USERNAME'] || CONFIG.fetch("jira_username") || raise("JIRA usernane")
JIRA_PASSWORD = ENV['JIRA_PASSWORD'] || CONFIG.fetch("jira_password") || raise("JIRA pwd")

class JiraEntry
  include HTTParty
  include Virtus
  base_uri JIRA_URI

  attribute :issue_id, String
  attribute :minutes, Integer
  attribute :comment, String
  attribute :date, Date

  def save!
    body = JSON.generate(
      {
        timeSpent: time_spent,
        comment: comment,
        started: Time.new(date.year, date.month, date.day, 18).strftime('%FT%T.000%z')
      })
    r = self.class.post("/rest/api/2/issue/#{issue_id}/worklog",
                        basic_auth: {username: JIRA_USERNAME, password: JIRA_PASSWORD},
                          body: body,
                          headers: { 'Content-Type' => 'application/json' })

    unless r.code == 201 && r.parsed_response["self"]
      raise StandardError, r.parsed_response.inspect
    end
  end

  def time_spent
    "#{minutes}m"
  end
end

#class FreckleApi < ActiveResource::Base
#self.site = FRECKLE_URI
#end

#class FreckleEntry < FreckleApi
#self.headers["X-FreckleToken"] = FRECKLE_TOKEN
#self.element_name = "entry"

#def self.on(date)
#find(:all, params: {"search[from]" => date.to_date, "search[to]" => date.to_date})
#end
#end

class Entry
  def self.build(freckle_entry)
    new(freckle_entry)
  end

  attr_reader :freckle_entry

  def initialize(freckle_entry)
    @freckle_entry = freckle_entry
  end

  def to_s
    "#{issue_id} - #{minutes}m - #{activity_id} - #{comment}"
  end

  def save!
    if valid?
      jira_entry.save!
    end
  end

  def valid?
    project_id && activity_id
  end

  def issue_id
    if valid?
      TicketMapping.call(project_id, activity_id)
    else
      nil
    end
  end

  def project_id
    ProjectMapping.call(freckle_entry.project_id)
  end

  def date
    freckle_entry.date
  end

  def minutes
    freckle_entry.minutes
  end

  def activity_id
    freckle_entry.activity_name
    #case comment.downcase
    #when /review/, /merge/
    #:dev
    #when /meeting/, /stand ?up/
    #:meeting
    #when /planning/
    #:meeting
    #when /train/
    #:training
    #else
    #:dev
    #end
  end

  def comment
    #freckle_entry.description.gsub(/!?#.*$/, '').gsub(/,\s*$/, '')
    freckle_entry.description
  end

  private

  def jira_entry
    JiraEntry.new(
      issue_id: issue_id,
      date: date,
      minutes: minutes,
      comment: comment
    )
  end

end

class TempoClient

  def initialize(args = ARGV)
    @day = if args && args[0]
             Chronic.parse(args[0], context: :past)
           end
  end

  def with_dry_run
    @dry_run = true
    self
  end

  def run
    if @day
      fetch_entries_and_push(@day)
    else
      ((last_push_date + 1.day).to_date.upto(Date.today)).each do |day|
        fetch_entries_and_push(day)
      end
    end

  end

  def fetch_entries_and_push(day)
    puts day.inspect

    entries = HarvestEntriesFetcher.on(day).map do |e|
      Entry.build(e)
    end.select(&:valid?)

    entries.each do |entry|
      puts entry
    end

    duration = entries.sum(&:minutes)
    hours = duration / 60
    minutes = duration % 60

    puts "Duration: #{hours}h #{minutes}m"

    return if entries.empty?

    puts "Push?"

    if $stdin.gets.chomp == "y"
      entries.map do |entry|
        puts "=> #{entry}"
        entry.save! unless @dry_run
      end

      update_last_push!(day) unless @dry_run

      puts "Done!"
      puts ""
    end
  end

  def last_push_date
    if File.exists?(".last-push")
      YAML.load_file(".last-push")
    else
      Time.new(2013, 05, 31).to_date
    end
  end

  def update_last_push!(date)
    File.open(".last-push", 'w') do |f|
      f.puts YAML::dump(date)
      f.puts ""
    end
  end

end

