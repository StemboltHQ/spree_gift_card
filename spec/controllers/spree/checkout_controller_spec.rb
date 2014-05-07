require 'spec_helper'

describe Spree::CheckoutController do
  let(:user) { create :user }
  let(:order) { create :order_with_totals, user: user }
  let(:valid_params) {{ use_route: spree, id: order.to_param, state: "address" }}

  before do
    allow(controller).to receive(:try_current_spree_user).and_return(user)
    allow(controller).to receive(:current_spree_user).and_return(user)
    allow(controller).to receive(:authorize!).and_return(true)
  end

  describe "PUT update" do
    subject { put :update, valid_params }
    before do
      session[:order_id] = order.id
    end

    describe "gift cards are recalculated on update if they exist" do
      let!(:gc) { create :gift_card }

      before do
        gc.apply(order)
      end

      it "tells the gift card to recalculate the adjustment" do
        expect_any_instance_of(Spree::GiftCard).to(
          receive(:update_adjustment).
          with(order.reload.adjustments.first, order)
        )

        subject
      end
    end
  end
end
