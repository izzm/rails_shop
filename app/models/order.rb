class Order < ActiveRecord::Base
  belongs_to :customer

  has_many :order_goods, :dependent => :destroy
  has_many :goods, :through => :order_goods
  accepts_nested_attributes_for :order_goods

  NEW_ORDER = "new_orders"
  COMPLETE = "complete"
  IN_PROGRESS = "in_progress"
  CANCELED = "canceled"

  STATES = [NEW_ORDER, IN_PROGRESS, COMPLETE]

  default_scope order('created_at desc')
 
  scope :canceled, where(:canceled => true)
  scope :active, where(:canceled => [false, nil])
  
  scope :all_orders, where("1=1") # Ugly hack for active admin
  scope :new_orders, where(:state => NEW_ORDER).active
  scope :in_progress,  where(:state => IN_PROGRESS).active
  scope :complete, where(:state => COMPLETE).active
  
  scope :articul_contains, lambda { |articul|
    joins(:goods).where(["goods.articul ilike ?", '%'+articul+'%'])
  }
  search_methods :articul_contains

  before_create :assign_number, :set_new_state
  after_create :set_customer_first_order

  validates :delivery_type, :presence => true
  validates :address, :length => { :maximum => 255 }
  validates :comment, :length => { :maximum => 1000 }
  validates :customer, :presence => true
  validates :discount, :numericality => {
    :greater_than_or_equal_to => 0, 
    :less_than_or_equal_to    => 100
  }
  validates :state, :presence => true
  
#  def self.find_with_product(product)
#    return [] unless product
#    
#    self.complete.includes(:line_items).
#      where(["line_items.product_id = ?", product.id]).
#      order("orders.checked_out_at DESC")
#  end

  def checkout!
    self.checked_out_at = Time.now
    self.save
  end

  def recalculate_price!
    self.total_price = order_goods.inject(0.0){|sum, line_item| sum += line_item.price }
    save!
  end

#  def state
#    super || (self.canceled ? CANCELED :
#      (!checked_out_at.nil? ? COMPLETE :
#        (delivery_at.nil? ? NEW_ORDER : IN_PROGRESS)))
#  end

  def display_name
    ActionController::Base.helpers.number_to_currency(total_price) + 
       " - Order ##{number} (#{customer.try(:name)})"
  end
  
  def total_price_with_discount
    self.total_price * (1 - (self.discount.to_i / 100.0))
  end

protected
  def set_new_state
    self.state ||= NEW_ORDER
  end

  def assign_number
    order_of_day = self.class.where("date_trunc('day', created_at) = date_trunc('day', TIMESTAMP ?)", Date.today).count + 1

    self.number = Date.today.strftime("%d%m%y") +
                  "-" + order_of_day.to_s
  end

  def delivery_type_code
    case self.delivery_type
      when 'delivery'
        "dl"
      else
        "sm"
    end
  end

  def set_customer_first_order
    self.customer.set_first_order! self
  end
end
