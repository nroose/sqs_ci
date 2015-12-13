require 'rails_helper'

RSpec.describe "posts/new", type: :view do
  before(:each) do
    assign(:post, Post.new(
      :name => "MyString",
      :body => "MyString"
    ))
  end

  after(:each) do
    sleep 30.seconds
  end

  it "renders new post form" do
    render

    assert_select "form[action=?][method=?]", posts_path, "post" do

      assert_select "input#post_name[name=?]", "post[name]"

      assert_select "input#post_body[name=?]", "post[body]"
    end
  end
end
