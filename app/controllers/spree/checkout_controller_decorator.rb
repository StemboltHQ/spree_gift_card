Spree::CheckoutController.class_eval do

  Spree::PermittedAttributes.checkout_attributes << :gift_code

  append_before_filter :add_gift_code, only: :update
  append_before_filter :recalculate_gift_cards, only: :update

  private

  def add_gift_code
    if object_params[:gift_code]
      @order.gift_code = object_params[:gift_code]
      unless apply_gift_code
        flash[:error] = Spree.t(:gc_apply_failure)
        render :edit
        return
      end
    end
  end

  def recalculate_gift_cards
    adjustments = @order.adjustments.gift_card
    adjustments.each do |adj|
      adj.originator.update_adjustment(adj, @order)
    end
    true
  end
end
