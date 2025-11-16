class User < ApplicationRecord
  has_many :scheduling_members, class_name: 'Scheduling::Member', dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :first_name, :last_name, presence: true

  def full_name
    "#{first_name} #{last_name}".strip
  end
end
