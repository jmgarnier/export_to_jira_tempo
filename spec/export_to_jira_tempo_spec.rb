require "spec_helper"
require 'active_support/all'
require_relative '../lib/export_to_jira_tempo'

describe "ExportToJiraTempo script" do

  describe HarvestEntriesFetcher do

    before :all do
      @entry = HarvestEntriesFetcher.on(Date.yesterday).last
    end

    it "gets the date" do
      puts @entry.inspect
      @entry.date.should == Date.yesterday
    end

    it "get the minutes" do
      @entry.minutes.should == 97.8
    end

    it "gets the project_id" do
      @entry.project_id.should == "3387190"
    end

    it "get the activity_name" do
      @entry.activity_name.should == :meeting
    end

    it "get the comment" do
      @entry.comment.should == "Standup, Planning"
    end
  end

  describe "Harvest integration with Phi's script" do

    it "just works" do
      date = "July 8th 2013"
      #TempoClient.new([datey]).with_dry_run.run
      TempoClient.new.run
    end
  end
end
