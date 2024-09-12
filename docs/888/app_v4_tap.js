// https://docs.ethers.org/v6/getting-started/
let provider = null;
let signer = null;
let wallet = null;
let contract = null;
let reader = new ethers.Contract(TOKEN_ADDR, ERC20_ABI, new ethers.JsonRpcProvider(CHAIN_RPC));
let raw_chain_id = null;

// main
let tweet_modal = new bootstrap.Modal($('.modal')[0]);
let tweet_url = 'https://twitter.com/intent/tweet?text=' + encodeURIComponent(TWEET_TEXT);
$('.btn-tweet').attr('href', tweet_url);
$('.btn-contact-team').attr('href', 'https://discord.gg/blobz');
$('#bridge').click(_ => window.open('https://app.optimism.io/bridge/deposit'));

// main: woohoo
$('.woohoo').click(_ => show_app_screen());
$('#blobz').click(evt => new_win('https://x.com/BLOBz4844', evt));
$('#poopz').click(evt => new_win('https://x.com/poopzter', evt));
$('#spread').click(evt => new_win(tweet_url, evt));

// main: delay
// TODO

// enable tooltips
const tooltipTriggerList = document.querySelectorAll('[data-bs-toggle="tooltip"]');
const tooltipList = [...tooltipTriggerList].map(tooltipTriggerEl => new bootstrap.Tooltip(tooltipTriggerEl));

// connect button
$('#connect').click(async _ => {
  if (window.ethereum === undefined) {
    show_error_modal(null, 'Please open by MetaMask');
    return;
  }

  // press button effect
  $('#connect').addClass('disabled');

  // connect metamask
  provider = new ethers.BrowserProvider(window.ethereum)
  signer = await provider.getSigner();

  // switch chain
  let changed = await switch_chain();
  if (changed) return;

  console.log('💬', 'connecting wallet..');
  contract = new ethers.Contract(CONTRACT_ADDR, CONTRACT_ABI, signer);

  // get claimable token
  let raw = await contract.getFunction('calcClaimAmount').staticCall(signer.address);
  let qty = ethers.formatUnits(raw.toString(), TOKEN_DECIMALS);

  // update balance
  load_balance(signer.address);

  // update connect/disconnect buttons
  hide_connect();
  $('#bridge').addClass('d-none');
  show_disconnect();

  // update claim button
  let msg = 'Nothing to claim';
  if (qty > 0)  {
    msg = `Claim ${format_num(qty)} ${TOKEN_SYMBOL}`;
    //play_party_effect();
  }
  $('#claim')
    .text(msg)
    .removeClass('d-none');
});
$('#disconnect').click(_ => {
  $('#connect')
    .removeClass('disabled')
    .removeClass('d-none');
  $('#bridge')
    .removeClass('d-none');
  $('#claim')
    .removeClass('disabled')
    .addClass('d-none');
  $('#claiming').addClass('d-none');
  $('#msg').addClass('d-none');
  $('#balance').addClass('d-none');
  $('#disconnect').addClass('d-none');
  tweet_modal.hide();
});

// claim button
$('#claim').click(async _ => {
  $('#claim').addClass('d-none');
  $('#claiming').removeClass('d-none');
  // recheck chain before claim
  let [ok, msg] = await validate_chain();
  if (!ok) {
    $('#claim').removeClass('d-none');
    $('#claiming').addClass('d-none');
    show_error_modal(msg);
    return;
  }
  // claim
  claim_by_gas_rate(contract, MINT_GAS_RATE)
    .then(tx => {
      console.log(tx);
      return tx.wait();
    })
    .then(receipt => { // https://docs.ethers.org/v6/api/providers/#TransactionReceipt
      console.log(receipt);
      $('#claiming').addClass('d-none');
      if (receipt.status != 1) { // 1 success, 0 revert
        show_error_modal(JSON.stringify(receipt.toJSON()));
        $('#claim').removeClass('d-none');
        return;
      }
      if (TWEET_TEXT) show_success_modal();
      play_party_effect();
      $('#claim').removeClass('d-none');
      load_balance(signer.address);
    })
    .catch(e => {
      $('#claim').removeClass('d-none');
      $('#claiming').addClass('d-none');

      // TODO Please try again in 52 seconds.
      if (e.reason != 'rejected') show_error_modal(e);

    });
});

if (window.ethereum) {
  // reconnect when switch account
  window.ethereum.on('accountsChanged', function (accounts) {
    console.log('💬', 'changed account');
    $('#disconnect').click();
    is_chain_ready(_ => $('#connect').click());
  });
  // disconnect when switch chain
  window.ethereum.on('chainChanged', function (networkId) {
    raw_chain_id = networkId;
    console.log('💬', 'changed chain');
    $('#disconnect').click();
    is_chain_ready(_ => $('#connect').click());
  });
}

// web3 functions
function is_chain_ready(callback) {
  let ready = parseInt(raw_chain_id) == CHAIN_ID;
  if (ready && callback) callback();
  return ready;
}
function handle_chain_exception(err) {
  let msg = `Please change network to [${CHAIN_NAME}] before claim.`;
  let info = `[${err.code}] ${err.message}`
  show_error_modal(info, msg);
  $('#connect').removeClass('disabled');
}
async function validate_chain() {
  // https://ethereum.stackexchange.com/questions/134610/metamask-detectethereumprovider-check-is-connected-to-specific-chain
  let chainId = null;
  try {
    let network = await provider.getNetwork();
    chainId = network.chainId;
  }
  catch(error) {
    console.log('🚨', error);
  }
  raw_chain_id = chainId;
  let ok = is_chain_ready();
  let msg = ok ? null : `Please change network to [${CHAIN_NAME}] before claim.`;
  return [ ok, msg ];
}
async function switch_chain() {
  // https://docs.metamask.io/wallet/reference/wallet_addethereumchain/
  let [ok, _] = await validate_chain();
  if (ok) return false;
  // switch chain
  try {
    await window.ethereum.request({
      "method": "wallet_switchEthereumChain",
      "params": [
        {
          "chainId": "0x" + CHAIN_ID.toString(16),
        }
      ]
    });
    return true;
  }
  // if chain not found, add chain
  catch(error) {
    if ([-32603, 4902].includes(error.code)) { // chain not added
      try {
        await window.ethereum.request({
          "method": "wallet_addEthereumChain",
          "params": [
            {
              "chainId": "0x" + CHAIN_ID.toString(16),
              "chainName": CHAIN_NAME,
              "rpcUrls": [
                CHAIN_RPC,
              ],
              //"iconUrls": [
              //  "https://xdaichain.com/fake/example/url/xdai.svg",
              //  "https://xdaichain.com/fake/example/url/xdai.png"
              //],
              "nativeCurrency": {
                "name": CHAIN_SYMBOL,
                "symbol": CHAIN_SYMBOL,
                "decimals": 18
              },
              "blockExplorerUrls": [
                CHAIN_EXPLORER,
              ]
            }
          ]
        });
      }
      catch(error) {
        handle_chain_exception(error);
      }
    }
    else {
      handle_chain_exception(error);
    }
    return true;
  }
}
async function claim_by_gas_rate(contract, gas_rate=1) {
  if (gas_rate == 1) {
    return contract.getFunction('claim').send();
  }
  else {
    let fn = contract.getFunction('claim');
    let params = [];
    let gas_limit = await fn.estimateGas(...params);
    gas_limit = Math.ceil(Number(gas_limit) * gas_rate);
    return fn.send(...params, { gasLimit: gas_limit });
  }
}
async function load_contract_obj() { // for console use
  provider = new ethers.BrowserProvider(window.ethereum)
  signer = await provider.getSigner();
  let [ok, msg] = await validate_chain();
  if (!ok) { console.warn(msg); return; }
  contract = new ethers.Contract(CONTRACT_ADDR, CONTRACT_ABI, signer);
  console.log('done');
}
function load_balance(addr) {
  // https://getbootstrap.com/docs/5.3/components/spinners/
  let html_spinner = `<div class="spinner-grow spinner-grow-sm" role="status"><span class="visually-hidden">Loading...</span></div>`;
  $('#balance').html(html_spinner).removeClass('d-none');
  reader.balanceOf(addr).then(raw => {
    let balance = ethers.formatUnits(raw.toString(), TOKEN_DECIMALS);
    $('#balance').text(`Balance: ${format_num(balance)} ${TOKEN_SYMBOL}`);
  });
}

// party
party.resolvableShapes['blobz_coin'] = `<img src='/888/assets/BLOBZ coin.png' width='20'>`;
function play_party_effect() {
  party.confetti(document.body, {
      count: 120,
      size: 2,
      shapes: [ 'blobz_coin' ],
  });
}

// modal
let claim_success = false;
$('.modal')[0].addEventListener('hidden.bs.modal', evt => {
  // when success dialog is closed
  if (!claim_success) return;
  show_woohoo_screen();
});
function show_success_modal() {
  $('#h51').removeClass('d-none');
  $('#h52').addClass('d-none');
  $('.btn-tweet').removeClass('d-none');
  $('.btn-contact-team').addClass('d-none');
  claim_success = true;
  tweet_modal.show();
}
function show_error_modal(info=null, msg="Oops! There're some errors") {
  $('#h51').addClass('d-none');
  $('#h52').removeClass('d-none');
  $('#h52 span').html(msg);
  $('.btn-tweet').addClass('d-none');
  $('.btn-contact-team').removeClass('d-none');
  claim_success = false;
  tweet_modal.show();
  // error info
  $('#cry_face').off('click');
  if (info) {
    $('#cry_face').click(_ => alert(info));
    console.log('🚨', info);
  }
}

// screen
function show_app_screen() {
  $('.app').removeClass('d-none');
  $('.woohoo').addClass('d-none');
  $('.cooldown').addClass('d-none');
}
function show_woohoo_screen() {
  $('.app').addClass('d-none');
  $('.woohoo').removeClass('d-none');
  $('.cooldown').addClass('d-none');
}
function show_cooldown_screen(sec) {
  $('.app').addClass('d-none');
  $('.woohoo').addClass('d-none');
  $('.cooldown').removeClass('d-none');
}

// common
function short_addr(addr) {
  return addr.substr(0, 5) + '...' + addr.slice(-4);
}
function format_num(num, digits=2) {
  let abb = '';
  if (num >= 1_000_000_000) { // B
    num /= 1_000_000_000;
    abb = 'B';
  }
  else if (num >= 1_000_000) { // M
    num /= 1_000_000;
    abb = 'M';
  }
  num = num.toLocaleString('en-US', { maximumFractionDigits: digits });
  if (num.endsWith('.0')) num = num.slice(0, -2); // 123.0 -> 123
  return `${num}${abb}`;
}
function hide_connect() {
  return $('#connect').addClass('d-none');
}
function show_disconnect() {
  let btn = $('#disconnect').removeClass('d-none');
  if (signer != null) btn.text(`Disconnect ${short_addr(signer.address)}`);
  return btn;
}
function new_win(url, evt=null) {
  window.open(url);
  if (evt) evt.stopPropagation();
}
