require 'rails_helper'

RSpec.describe "posts/index", type: :view do
  before(:each) do
    assign(:posts, [
      Post.create!(
        :name => "Name",
        :body => "Body"
      ),
      Post.create!(
        :name => "Name",
        :body => "Body"
      )
    ])
  end

  after(:each) do
    sleep 30.seconds
  end

  it "renders a list of posts" do
    render
    assert_select "tr>td", :text => "Name".to_s, :count => 2
    assert_select "tr>td", :text => "Body".to_s, :count => 2
  end
end
