import { BigNumber } from 'ethers';
import { TransactionResponse } from '@ethersproject/providers';

export async function getGasFeeFromTx(tx: TransactionResponse) {
  if (tx && typeof tx.wait === 'function') {
    const { gasUsed, effectiveGasPrice } = await tx.wait()
    return gasUsed.mul(effectiveGasPrice)
  }
  return BigNumber.from(0)
}