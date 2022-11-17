import { logger } from './logger';
import Axios from 'axios';

(async () => {
  logger.info('[Start] Validating MSIG validators to add data...');

  const { validators } = await Axios.get<{ validators: { publicKey: string; statusCode: string }[] }>(
    'https://api.frax.finance/v2/frxeth/validators',
  ).then((r) => r.data);

  logger.info(`Got ${validators.length} validators from the API`);

  const { results } = await Axios.get<{
    results: {
      type: string;
      transaction?: { id: string; executionInfo: { nonce: number }; txInfo: { methodName: string; to: { value: string } } };
    }[];
  }>('https://safe-client.safe.global/v1/chains/1/safes/0x8306300ffd616049FD7e4b0354a64Da835c1A81C/transactions/queued').then(
    (r) => r.data,
  );

  const addValidatorTransactions = results.filter((f) => f.transaction?.txInfo.methodName === 'addValidators');

  logger.info(
    `Got ${results.filter((f) => f.type === 'TRANSACTION').length} transactions in the MSIG queue, ${
      addValidatorTransactions.length
    } of which are addValidators`,
  );

  const publicKeysToAdd: { key: string; nonce: number }[] = [];
  for (const tx of addValidatorTransactions) {
    if (tx.transaction) {
      const { txData } = await Axios.get<{
        txData: { dataDecoded: { method: string; parameters: { name: string; value: [string, string, string[]] }[] } };
      }>(`https://safe-client.safe.global/v1/chains/1/transactions/${tx.transaction?.id}`).then((r) => r.data);

      const validatorParams = txData.dataDecoded.parameters[0];

      if (tx.transaction.txInfo.to.value !== '0xbAFA44EFE7901E04E39Dad13167D089C559c1138') {
        logger.error(
          `[#${tx.transaction.executionInfo.nonce}] Wrong to_address of ${tx.transaction.txInfo.to.value}, should be 0xbAFA44EFE7901E04E39Dad13167D089C559c1138`,
        );
        continue;
      }

      if (txData.dataDecoded.method === 'addValidators' && validatorParams.name === 'validatorArray') {
        const txKeysToAdd = validatorParams.value.map((x) => ({ key: x[0], nonce: tx.transaction?.executionInfo.nonce ?? -1 }));
        publicKeysToAdd.push(...txKeysToAdd);
        logger.info(`For tx #${tx.transaction.executionInfo.nonce}, we got ${txKeysToAdd.length} validator public keys to add`);
      }
    }
  }

  logger.info(`Got a total of ${publicKeysToAdd.length} public keys to add`);

  const uniquePublicKeys = [...new Set(publicKeysToAdd.map((x) => x.key))];

  if (uniquePublicKeys.length !== publicKeysToAdd.length) {
    logger.error('Duplicate keys found in enqueued transactions');
    return;
  } else {
    logger.info(`There are no duplicate keys in the enqueued transactions`);
  }

  const keyStatuses = publicKeysToAdd.map((x) => ({
    key: x.key,
    status: validators.find((f) => f.publicKey === x.key)?.statusCode,
    nonce: x.nonce,
  }));

  const keysWithIssues = keyStatuses.filter((f) => f.status !== 'uninitialized');

  if (keysWithIssues.length > 0) {
    for (const item of keysWithIssues) {
      if (!item.status) {
        logger.error(`[#${item.nonce}] ${item.key} is missing from the API`);
      } else {
        logger.error(`[#${item.nonce}] ${item.key} has status ${item.status}`);
      }
    }

    logger.error(`Got ${keysWithIssues.length} total keys with issues`);
  } else {
    logger.info(`All ${keyStatuses.length} keys are good to go`);
  }

  logger.info('[End] Validated MSIG validators to add data');
})();