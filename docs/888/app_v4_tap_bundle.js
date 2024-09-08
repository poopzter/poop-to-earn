function load_script(src, callback=null) {
  var script = document.createElement('script');
  script.src = src;
  if (callback) script.onload = callback;
  document.body.appendChild(script);
}
load_script('/888/config.js?t=' + +(new Date()), _  => { // 1. load config (no cache)
  load_script('/888/abi_v4_tap.js', _ => {               // 2. load contract abi
    load_script('/888/abi_erc20.js', _ => {              // 3. load erc20 abi
      load_script('/888/app_v4_tap.js');                 // 4. load app
    });
  });
});
