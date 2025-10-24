class RemoveTitleAndBioFromSchedulingMembers < ActiveRecord::Migration[8.1]
  def change
    remove_column :scheduling_members, :title, :string
    remove_column :scheduling_members, :bio, :text
  end
end
