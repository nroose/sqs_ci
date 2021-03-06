require 'rails_helper'

RSpec.describe "posts/edit", type: :view do
  before(:each) do
    @post = assign(:post, Post.create!(
      :name => "MyString",
      :body => "MyString"
    ))
  end

  after(:each) do
    sleep 30.seconds
  end

  it "renders the edit post form" do
    render

    assert_select "form[action=?][method=?]", post_path(@post), "post" do

      assert_select "input#post_name[name=?]", "post[name]"

      assert_select "input#post_body[name=?]", "post[body]"
    end
  end
end
