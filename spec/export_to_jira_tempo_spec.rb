require "spec_helper"

describe ExportToJiraTempo do
  it "has a VERSION" do
    ExportToJiraTempo::VERSION.should =~ /^[\.\da-z]+$/
  end
end
