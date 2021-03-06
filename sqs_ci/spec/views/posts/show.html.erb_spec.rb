require 'rails_helper'

RSpec.describe "posts/show", type: :view do
  before(:each) do
    @post = assign(:post, Post.create!(
      :name => "Name",
      :body => "Body"
    ))
  end

  after(:each) do
    sleep 30.seconds
  end

  it "renders attributes in <p>" do
    render
    expect(rendered).to match(/Name/)
    expect(rendered).to match(/Body/)
  end
end
