def test_default(token, swapContract, accounts):
    swap_limits = [10, 30, 50]

    (swap_limits_new, amount_to_pay, amount_to_receive) = swapContract.calculateAmountsAfterSwap(
        swap_limits, 90, True
    )
    print(swap_limits_new, amount_to_pay, amount_to_receive)
    assert swap_limits_new == [0, 0, 0]
    assert amount_to_pay == 90
    assert amount_to_receive == 30


def test_amount_to_send_more_then_amount_to_pay(token, swapContract, accounts):
    swap_limits = [10, 30, 50]

    (swap_limits_new, amount_to_pay, amount_to_receive) = swapContract.calculateAmountsAfterSwap(
        swap_limits, 100, True
    )
    print(swap_limits_new, amount_to_pay, amount_to_receive)
    assert swap_limits_new == [0, 0, 0]
    assert amount_to_pay == 90
    assert amount_to_receive == 30
