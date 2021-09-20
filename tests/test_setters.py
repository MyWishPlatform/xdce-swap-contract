def test_setSwapRatio(token, swapContract):
    swapContract.setSwapRatio(0, 3)
    assert swapContract.swapRatios(0) == 3
    swapContract.setSwapRatio(1, 5)
    assert swapContract.swapRatios(1) == 5
    swapContract.setSwapRatio(1, 7)
    assert swapContract.swapRatios(1) == 7


def test_setMinSwapAmountPerTx(token, swapContract):
    swapContract.setMinSwapAmountPerTx(10)
    assert swapContract.minSwapAmountPerTx() == 10


def test_setMaxSwapAmountPerTx(token, swapContract):
    swapContract.setMaxSwapAmountPerTx(10)
    assert swapContract.maxSwapAmountPerTx() == 10


def test_enableSwap(token, swapContract):
    swapContract.enableSwap(0)
    swapContract.enableSwap(1)
    swapContract.enableSwap(2)
    assert swapContract.swapEnabled(0)
    assert swapContract.swapEnabled(1)
    assert swapContract.swapEnabled(2)


def test_disableSwap(token, swapContract):
    swapContract.disableSwap(0)
    swapContract.disableSwap(1)
    swapContract.disableSwap(2)
    assert not swapContract.swapEnabled(0)
    assert not swapContract.swapEnabled(1)
    assert not swapContract.swapEnabled(2)
