var freeaps_basalSetTemp;freeaps_basalSetTemp=(()=>{var t={1701:(t,r,e)=>{"use strict";function a(t,r){t.reason=(t.reason?t.reason+". ":"")+r,console.error(r)}var n={getMaxSafeBasal:function(t){var r=isNaN(t.max_daily_safety_multiplier)||null===t.max_daily_safety_multiplier?3:t.max_daily_safety_multiplier,e=isNaN(t.current_basal_safety_multiplier)||null===t.current_basal_safety_multiplier?4:t.current_basal_safety_multiplier;return Math.min(t.max_basal,r*t.max_daily_basal,e*t.current_basal)},setTempBasal:function(t,r,o,i,u){var s=n.getMaxSafeBasal(o);t<0?t=0:t>s&&(t=s);var l=e(6880)(t,o);return void 0!==u&&void 0!==u.duration&&void 0!==u.rate&&u.duration>r-10&&u.duration<=120&&l<=1.2*u.rate&&l>=.8*u.rate&&r>0?(i.reason+=" "+u.duration+"min kvar av nuvarande "+u.rate+"E/h ~ behov "+l+"E/h: Ingen ny temp basal krävs",i):l===o.current_basal?!0===o.skip_neutral_temps?void 0!==u&&void 0!==u.duration&&u.duration>0?(a(i,"Föreslagen basal är samma som basal i profil, en temp basal är aktiv, avbryter den"),i.duration=0,i.rate=0,i):(a(i,"Föreslagen basal är samma som basal i profil, ingen temp basal är aktiv, ingen åtgärd krävs"),i):(a(i,"Ställer in neutral temp basal på "+o.current_basal+"E/h"),i.duration=r,i.rate=l,i):(i.duration=r,i.rate=l,i)}};t.exports=n},6880:(t,r,e)=>{var a=e(6654);t.exports=function(t,r){var e=20;void 0!==r&&"string"==typeof r.model&&(a(r.model,"54")||a(r.model,"23"))&&(e=40);return t<1?Math.round(t*e)/e:t<10?Math.round(20*t)/20:Math.round(10*t)/10}},2705:(t,r,e)=>{var a=e(5639).Symbol;t.exports=a},9932:t=>{t.exports=function(t,r){for(var e=-1,a=null==t?0:t.length,n=Array(a);++e<a;)n[e]=r(t[e],e,t);return n}},9750:t=>{t.exports=function(t,r,e){return t==t&&(void 0!==e&&(t=t<=e?t:e),void 0!==r&&(t=t>=r?t:r)),t}},4239:(t,r,e)=>{var a=e(2705),n=e(9607),o=e(2333),i=a?a.toStringTag:void 0;t.exports=function(t){return null==t?void 0===t?"[object Undefined]":"[object Null]":i&&i in Object(t)?n(t):o(t)}},531:(t,r,e)=>{var a=e(2705),n=e(9932),o=e(1469),i=e(3448),u=a?a.prototype:void 0,s=u?u.toString:void 0;t.exports=function t(r){if("string"==typeof r)return r;if(o(r))return n(r,t)+"";if(i(r))return s?s.call(r):"";var e=r+"";return"0"==e&&1/r==-Infinity?"-0":e}},1957:(t,r,e)=>{var a="object"==typeof e.g&&e.g&&e.g.Object===Object&&e.g;t.exports=a},9607:(t,r,e)=>{var a=e(2705),n=Object.prototype,o=n.hasOwnProperty,i=n.toString,u=a?a.toStringTag:void 0;t.exports=function(t){var r=o.call(t,u),e=t[u];try{t[u]=void 0;var a=!0}catch(t){}var n=i.call(t);return a&&(r?t[u]=e:delete t[u]),n}},2333:t=>{var r=Object.prototype.toString;t.exports=function(t){return r.call(t)}},5639:(t,r,e)=>{var a=e(1957),n="object"==typeof self&&self&&self.Object===Object&&self,o=a||n||Function("return this")();t.exports=o},6654:(t,r,e)=>{var a=e(9750),n=e(531),o=e(554),i=e(9833);t.exports=function(t,r,e){t=i(t),r=n(r);var u=t.length,s=e=void 0===e?u:a(o(e),0,u);return(e-=r.length)>=0&&t.slice(e,s)==r}},1469:t=>{var r=Array.isArray;t.exports=r},3218:t=>{t.exports=function(t){var r=typeof t;return null!=t&&("object"==r||"function"==r)}},7005:t=>{t.exports=function(t){return null!=t&&"object"==typeof t}},3448:(t,r,e)=>{var a=e(4239),n=e(7005);t.exports=function(t){return"symbol"==typeof t||n(t)&&"[object Symbol]"==a(t)}},8601:(t,r,e)=>{var a=e(4841),n=1/0;t.exports=function(t){return t?(t=a(t))===n||t===-1/0?17976931348623157e292*(t<0?-1:1):t==t?t:0:0===t?t:0}},554:(t,r,e)=>{var a=e(8601);t.exports=function(t){var r=a(t),e=r%1;return r==r?e?r-e:r:0}},4841:(t,r,e)=>{var a=e(3218),n=e(3448),o=/^\s+|\s+$/g,i=/^[-+]0x[0-9a-f]+$/i,u=/^0b[01]+$/i,s=/^0o[0-7]+$/i,l=parseInt;t.exports=function(t){if("number"==typeof t)return t;if(n(t))return NaN;if(a(t)){var r="function"==typeof t.valueOf?t.valueOf():t;t=a(r)?r+"":r}if("string"!=typeof t)return 0===t?t:+t;t=t.replace(o,"");var e=u.test(t);return e||s.test(t)?l(t.slice(2),e?2:8):i.test(t)?NaN:+t}},9833:(t,r,e)=>{var a=e(531);t.exports=function(t){return null==t?"":a(t)}}},r={};function e(a){if(r[a])return r[a].exports;var n=r[a]={exports:{}};return t[a](n,n.exports,e),n.exports}return e.g=function(){if("object"==typeof globalThis)return globalThis;try{return this||new Function("return this")()}catch(t){if("object"==typeof window)return window}}(),e(1701)})();
