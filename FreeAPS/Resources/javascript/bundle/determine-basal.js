var freeaps_determineBasal;(()=>{var e={5546:(e,t,a)=>{var r=a(6880);function o(e,t){t||(t=0);var a=Math.pow(10,t);return Math.round(e*a)/a}function n(e,t){return"mmol/L"===t.out_units?o(.0555*e,1):Math.round(e)}e.exports=function(e,t,a,i,s,l,u,m,d,c,g,h,p,v,f){var B=i.min_bg,b=v.overrideTarget;0!=b&&6!=b&&v.useOverride&&!i.temptargetSet&&(B=b);v.smbIsOff;const M=v.advancedSettings,_=v.isfAndCr,y=v.isf,x=v.cr;v.smbIsAlwaysOff,v.start;v.end;const S=v.smbMinutes,D=v.uamMinutes;var w=h.useNewFormula,G=0,T=B,C=0,U="",O="",A="",R="",I="",F="",j=0,P=0,E=0,q=0,W=0,k=0;const L=v.weightedAverage;var z=1,N=i.sens,H=i.carb_ratio;v.useOverride&&(z=v.overridePercentage/100,_?(N/=z,H/=z):(x&&(H/=z),y&&(N/=z)));const Z=i.weightPercentage,$=v.average_total_data;function J(e,t){var a=e.getTime();return new Date(a+36e5*t)}function K(e){var t=i.bolus_increment;.1!=t&&(t=.05);var a=e/t;return a>=1?o(Math.floor(a)*t,5):0}function Q(e){function t(e){return e<10&&(e="0"+e),e}return t(e.getHours())+":"+t(e.getMinutes())+":00"}function V(e,t){var a=new Date("1/1/1999 "+e),r=new Date("1/1/1999 "+t);return(a.getTime()-r.getTime())/36e5}const X=Math.min(i.autosens_min,i.autosens_max),Y=Math.max(i.autosens_min,i.autosens_max);function ee(e,t){var a=0,r=t,o=(e-t)/36e5,n=0,i=o,s=0;do{if(o>0){var l=Q(r),u=p[0].rate;for(let e=0;e<p.length;e++){var m=p[e].start;if(l==m){if(e+1<p.length){o>=(s=V(p[e+1].start,p[e].start))?n=s:o<s&&(n=o)}else if(e+1==p.length){let t=p[0].start;s=24-V(p[e].start,t),o>=s?n=s:o<s&&(n=o)}a+=K((u=p[e].rate)*n),o-=n,console.log("Dynamic ratios log: scheduled insulin added: "+K(u*n)+" E. Bas duration: "+n.toPrecision(3)+" h. Base Rate: "+u+" E/h. Time :"+l),r=J(r,n)}else if(l>m)if(e+1<p.length){var d=p[e+1].start;l<d&&(o>=(s=V(d,l))?n=s:o<s&&(n=o),a+=K((u=p[e].rate)*n),o-=n,console.log("Dynamic ratios log: scheduled insulin added: "+K(u*n)+" E. Bas duration: "+n.toPrecision(3)+" h. Base Rate: "+u+" E/h. Time :"+l),r=J(r,n))}else if(e==p.length-1){o>=(s=V("23:59:59",l))?n=s:o<s&&(n=o),a+=K((u=p[e].rate)*n),o-=n,console.log("Dynamic ratios log: scheduled insulin added: "+K(u*n)+" E. Bas duration: "+n.toPrecision(3)+" h. Base Rate: "+u+" E/h. Time :"+l),r=J(r,n)}}}}while(o>0&&o<i);return a}if((Y==X||Y<1||X>1)&&(w=!1,console.log("Dynamic ISF disabled due to current autosens settings")),g.length){if(w){let e=g.length-1;var te=new Date(g[e].timestamp),ae=new Date(g[0].timestamp);if("TempBasalDuration"==g[0]._type&&(ae=new Date),(C=(ae-te)/36e5)<23.9&&C>21)W=ee(te,(re=24-C,oe=te.getTime(),new Date(oe-36e5*re))),R="24 hours of data is required for an accurate tdd calculation. Currently only "+C.toPrecision(3)+" hours of pump history data are available. Using your pump scheduled basals to fill in the missing hours. Scheduled basals added: "+W.toPrecision(5)+" E. ";else C<21?(w=!1,enableDynamicCR=!1):R=""}}else console.log("Pumphistory is empty!"),w=!1,enableDynamicCR=!1;var re,oe;if(w){for(let e=0;e<g.length;e++)"Bolus"==g[e]._type&&(q+=g[e].amount);for(let e=1;e<g.length;e++)if("TempBasal"==g[e]._type&&g[e].rate>0){j=e,k=g[e].rate;var ne=g[e-1]["duration (min)"]/60,ie=ne,se=new Date(g[e-1].timestamp),le=se,ue=0;do{if(e--,0==e){le=new Date;break}if("TempBasal"==g[e]._type||"PumpSuspend"==g[e]._type){le=new Date(g[e].timestamp);break}var me=e-2;if(me>=0&&"Rewind"==g[me]._type){let e=g[me].timestamp;for(;me-1>=0&&"Prime"==g[me-=1]._type;)ue=(g[me].timestamp-e)/36e5;ue>=ne&&(le=e,ue=0)}}while(e>0);var de=(le-se)/36e5;de<ie&&(ne=de),E+=K(k*(ne-ue)),e=j}for(let e=0;e<g.length;e++)if(0,0==g[e]["duration (min)"]||"PumpResume"==g[e]._type){let t=new Date(g[e].timestamp),a=t,r=e;do{if(r>0&&(--r,"TempBasal"==g[r]._type)){a=new Date(g[r].timestamp);break}}while(r>0);(a-t)/36e5>0&&(W+=ee(a,t))}for(let e=g.length-1;e>0;e--)if("TempBasalDuration"==g[e]._type){let t=g[e]["duration (min)"]/60,a=new Date(g[e].timestamp);var ce=a;let r=e;do{if(--r,r>=0&&("TempBasal"==g[r]._type||"PumpSuspend"==g[r]._type)){ce=new Date(g[r].timestamp);break}}while(r>0);if(0==e&&"TempBasalDuration"==g[0]._type&&(ce=new Date,t=g[e]["duration (min)"]/60),(ce-a)/36e5-t>0){W+=ee(ce,J(a,t))}}var ge={TDD:o(P=q+E+W,5),bolus:o(q,5),temp_basal:o(E,5),scheduled_basal:o(W,5)};C>21?(O=". Bolus insulin: "+q.toPrecision(5)+" E",A=". Temporary basal insulin: "+E.toPrecision(5)+" E",U=". Insulin with scheduled basal rate: "+W.toPrecision(5)+" E",I=R+(" TDD past 24h is: "+P.toPrecision(5)+" E")+O+A+U,F=", TDD: "+o(P,2)+" E, "+o(q/P*100,0)+"% Bolus "+o((E+W)/P*100,0)+"% Basal"):F=", TDD: Not enough pumpData (< 21h)"}var he;const pe=e.glucose,ve=h.enableDynamicCR,fe=h.adjustmentFactor,Be=B;var be=!1,Me="",_e=1,ye="";$>0&&(_e=L/$),ye=_e>1?"Basal adjustment with a 24 hour  to total average (up to 14 days of data) TDD ratio (limited by Autosens max setting). Basal Ratio: "+(_e=o(_e=Math.min(_e,i.autosens_max),2))+". Upper limit = Autosens max ("+i.autosens_max+")":_e<1?"Basal adjustment with a 24 hour to  to total average (up to 14 days of data) TDD ratio (limited by Autosens min setting). Basal Ratio: "+(_e=o(_e=Math.max(_e,i.autosens_min),2))+". Lower limit = Autosens min ("+i.autosens_min+")":"Basal adjusted with a 24 hour to total average (up to 14 days of data) TDD ratio: "+_e,ye=", Basal ratio: "+_e,(i.high_temptarget_raises_sensitivity||i.exercise_mode||v.isEnabled)&&(be=!0),Be>=118&&be&&(w=!1,Me="Dynamic ISF temporarily off due to a high temp target/exercising. Current min target: "+Be);var xe=", Dynamic ratios log: ",Se=", AF: "+fe,De="BG: "+pe+" mg/dl ("+(.0555*pe).toPrecision(2)+" mmol/l)",we="",Ge="";const Te=h.curve,Ce=i.insulinPeakTime,Ue=h.useCustomPeakTime;var Oe=55,Ae=65;switch(Te){case"rapid-acting":Ae=65;break;case"ultra-rapid":Ae=50}Ue?(Oe=120-Ce,console.log("Custom insulinpeakTime set to :"+Ce+", insulinFactor: "+Oe)):(Oe=120-Ae,console.log("insulinFactor set to : "+Oe)),he=P,Z<1&&L>0&&(P=L,console.log("Using weighted TDD average: "+o(P,2)+" E, instead of past 24 h ("+o(he,2)+" E), weight: "+Z),Ge=", Weighted TDD: "+o(P,2)+" E");const Re=h.sigmoid;var Ie="";if(w){var Fe=N*fe*P*Math.log(pe/Oe+1)/1800;we=", Logarithmic formula"}if(w&&Re){const e=X,t=Y-e,a=.0555*(pe-B);var je=_e,Pe=Y-1;1==Y&&(Pe=Y+.01-1);const r=Math.log10(1/Pe-e/Pe)/Math.log10(Math.E),o=a*fe*je+r;Fe=t/(1+Math.exp(-o))+e,we=", Sigmoid På"}var Ee=H;const qe=o(H,1);var We="",ke="";if(w&&P>0){if(We=", Dynamisk ISF/CR: På/",Fe>Y?(Me=", Dynamic ISF limited by autosens_max setting: "+Y+" ("+o(Fe,2)+"), ",ke=", Autosens/Dynamic Limit: "+Y+" ("+o(Fe,2)+")",Fe=Y):Fe<X&&(Me=", Dynamic ISF limited by autosens_min setting: "+X+" ("+o(Fe,2)+"). ",ke=", Autosens/Dynamic Limit: "+X+" ("+o(Fe,2)+")",Fe=X),ve){We+="På";var Le=". New Dynamic CR: "+o(H/=Fe,1)+" g/E"}else Le=" CR: "+Ee+" g/E",We+="Av";const e=N/Fe;s.ratio=Fe,Ie=". Using Sigmoid function, the autosens ratio has been adjusted with sigmoid factor to: "+o(s.ratio,2)+". New ISF = "+o(e,2)+" mg/dl ("+o(.0555*e,2)+" (mmol/l). CR adjusted from "+o(qe,2)+" to "+o(H,2),Me+=Re?Ie:", Dynamic autosens.ratio set to "+o(Fe,2)+" with ISF: "+e.toPrecision(3)+" mg/dl/U ("+(.0555*e).toPrecision(3)+" mmol/l/U)",I+=xe+De+Se+we+Me+We+Le+Ge}else I+=xe+"Dynamic Settings disabled";console.log(I),w||ve?w&&i.tddAdjBasal?F+=We+we+ke+Se+ye:w&&!i.tddAdjBasal&&(F+=We+we+ke+Se):F+="",.5!=i.smb_delivery_ratio&&(F+=", SMB Ratio: "+i.smb_delivery_ratio),""!=f&&"Nothing changed"!=f&&(F+=", Middleware: "+f+" ");var ze={},Ne=new Date;if(c&&(Ne=c),void 0===i||void 0===i.current_basal)return ze.error="Error: could not get current basal rate",ze;var He=r(i.current_basal,i)*z,Ze=He;v.useOverride&&(0==v.duration?console.log("Profile Override is active. Override "+o(100*z,0)+"%. Override Duration: Enabled indefinitely"):console.log("Profile Override is active. Override "+o(100*z,0)+"%. Override Expires in: "+v.duration+" min."));var $e=new Date;c&&($e=c);var Je,Ke=new Date(e.date),Qe=o(($e-Ke)/60/1e3,1),Ve=e.glucose,Xe=e.noise;Je=e.delta>-.5?"+"+o(e.delta,0):o(e.delta,0);var Ye=Math.min(e.delta,e.short_avgdelta),et=Math.min(e.short_avgdelta,e.long_avgdelta),tt=Math.max(e.delta,e.short_avgdelta,e.long_avgdelta);(Ve<=10||38===Ve||Xe>=3)&&(ze.reason="CGM is calibrating, in ??? state, or noise is high");if(Ve>60&&0==e.delta&&e.short_avgdelta>-1&&e.short_avgdelta<1&&e.long_avgdelta>-1&&e.long_avgdelta<1&&400!=Ve&&("fakecgm"==e.device?(console.error("CGM data is unchanged ("+n(Ve,i)+"+"+n(e.delta,i)+") for 5m w/ "+n(e.short_avgdelta,i)+" mg/dL ~15m change & "+n(e.long_avgdelta,2)+" mg/dL ~45m change"),console.error("Simulator mode detected ("+e.device+"): continuing anyway")):400!=Ve&&!0),Qe>12||Qe<-5?ze.reason="If current system time "+$e+" is correct, then BG data is too old. The last BG data was read "+Qe+"m ago at "+Ke:0===e.short_avgdelta&&0===e.long_avgdelta&&400!=Ve&&(e.last_cal&&e.last_cal<3?ze.reason="CGM was just calibrated":ze.reason="CGM data is unchanged ("+n(Ve,i)+"+"+n(e.delta,i)+") for 5m w/ "+n(e.short_avgdelta,i)+" mg/dL ~15m change & "+n(e.long_avgdelta,i)+" mg/dL ~45m change"),400!=Ve&&(Ve<=10||38===Ve||Xe>=3||Qe>12||Qe<-5||0===e.short_avgdelta&&0===e.long_avgdelta))return t.rate>=Ze?(ze.reason+=". Canceling high temp basal of "+t.rate,ze.deliverAt=Ne,ze.temp="absolute",ze.duration=0,ze.rate=0,ze):0===t.rate&&t.duration>30?(ze.reason+=". Shortening "+t.duration+"m long zero temp to 30m. ",ze.deliverAt=Ne,ze.temp="absolute",ze.duration=30,ze.rate=0,ze):(ze.reason+=". Temp "+t.rate+" <= current basal "+Ze+"E/h; doing nothing. ",ze);var at,rt,ot,nt,it=i.max_iob;if(void 0!==B&&(rt=B),void 0!==i.max_bg&&(ot=B),void 0!==i.enableSMB_high_bg_target&&(nt=i.enableSMB_high_bg_target),void 0===B)return ze.error="Error: could not determine target_bg. ",ze;at=B;var st=i.exercise_mode||i.high_temptarget_raises_sensitivity||v.isEnabled,lt=100,ut=160;if(ut=i.half_basal_exercise_target,v.isEnabled){const e=v.hbt;console.log("Half Basal Target used: "+n(e,i)+" "+i.out_units),ut=e}else console.log("Default Half Basal Target used: "+n(ut,i)+" "+i.out_units);if(st&&i.temptargetSet&&at>lt||i.low_temptarget_lowers_sensitivity&&i.temptargetSet&&at<lt||v.isEnabled&&i.temptargetSet&&at<lt){var mt=ut-lt;sensitivityRatio=mt*(mt+at-lt)<=0?i.autosens_max:mt/(mt+at-lt),sensitivityRatio=Math.min(sensitivityRatio,i.autosens_max),sensitivityRatio=o(sensitivityRatio,2),process.stderr.write("Sensitivity ratio set to "+sensitivityRatio+" based on temp target of "+at+"; ")}else void 0!==s&&s&&(sensitivityRatio=s.ratio,0===b||6===b||b===i.min_bg||i.temptargetSet||(at=b,console.log("Current Override Profile Target: "+n(b,i)+" "+i.out_units)),process.stderr.write("Autosens ratio: "+sensitivityRatio+"; "));if(i.temptargetSet&&at<lt&&w&&pe>=at&&sensitivityRatio<Fe&&(s.ratio=Fe*(lt/at),s.ratio=Math.min(s.ratio,i.autosens_max),sensitivityRatio=o(s.ratio,2),console.log("Dynamic ratio increased from "+o(Fe,2)+" to "+o(s.ratio,2)+" due to a low temp target ("+at+").")),sensitivityRatio&&!w?(Ze=i.current_basal*z*sensitivityRatio,Ze=r(Ze,i)):w&&i.tddAdjBasal&&(Ze=i.current_basal*_e*z,Ze=r(Ze,i),$>0&&(process.stderr.write("TDD-adjustment of basals activated, using tdd24h_14d_Ratio "+o(_e,2)+", TDD 24h = "+o(he,2)+"E, Weighted average TDD = "+o(L,2)+"E, (Weight percentage = "+Z+"), Total data of TDDs (up to 14 days) average = "+o($,2)+"E. "),Ze!==He*z?process.stderr.write("Adjusting basal from "+He*z+" E/h to "+Ze+" E/h; "):process.stderr.write("Basal unchanged: "+Ze+" E/h; "))),i.temptargetSet);else if(void 0!==s&&s&&(i.sensitivity_raises_target&&s.ratio<1||i.resistance_lowers_target&&s.ratio>1)){rt=o((rt-60)/s.ratio)+60,ot=o((ot-60)/s.ratio)+60;var dt=o((at-60)/s.ratio)+60;at===(dt=Math.max(80,dt))?process.stderr.write("target_bg unchanged: "+n(dt,i)+"; "):process.stderr.write("target_bg from "+n(dt,i)+" to "+n(dt,i)+"; "),at=dt}var ct=n(at,i);at!=B&&(ct=0!==b&&6!==b&&b!==at?n(B,i)+"→"+n(b,i)+"→"+n(at,i):n(B,i)+"→"+n(at,i));var gt=200,ht=200,pt=200;if(e.noise>=2){var vt=Math.max(1.1,i.noisyCGMTargetMultiplier);Math.min(250,i.maxRaw);gt=o(Math.min(200,rt*vt)),ht=o(Math.min(200,at*vt)),pt=o(Math.min(200,ot*vt)),process.stderr.write("Raising target_bg for noisy / raw CGM data, from "+n(dt,i)+" to "+n(ht,i)+"; "),rt=gt,at=ht,ot=pt}T=rt-.5*(rt-40),T=Math.min(Math.max(i.threshold_setting,T,65),120),console.error("Threshold set to "+n(T,i));var ft="",Bt=(o(N,1),N);if(void 0!==s&&s&&((Bt=o(Bt=N/sensitivityRatio,1))!==N?process.stderr.write("ISF from "+n(N,i)+" to "+n(Bt,i)):process.stderr.write("ISF unchanged: "+n(Bt,i)),ft+="Autosens ratio: "+o(sensitivityRatio,2)+", ISF: "+n(N,i)+"→"+n(Bt,i)),console.error("CR:"+H),void 0===a)return ze.error="Error: iob_data undefined. ",ze;var bt,Mt=a;if(a.length,a.length>1&&(a=Mt[0]),void 0===a.activity||void 0===a.iob)return ze.error="Error: iob_data missing some property. ",ze;var _t=((bt=void 0!==a.lastTemp?o((new Date($e).getTime()-a.lastTemp.date)/6e4):0)+t.duration)%30;if(console.error("currenttemp:"+t.rate+" lastTempAge:"+bt+"m, tempModulus:"+_t+"m"),ze.temp="absolute",ze.deliverAt=Ne,m&&t&&a.lastTemp&&t.rate!==a.lastTemp.rate&&bt>10&&t.duration)return ze.reason="Warning: currenttemp rate "+t.rate+" != lastTemp rate "+a.lastTemp.rate+" from pumphistory; canceling temp",u.setTempBasal(0,0,i,ze,t);if(t&&a.lastTemp&&t.duration>0){var yt=bt-a.lastTemp.duration;if(yt>5&&bt>10)return ze.reason="Warning: currenttemp running but lastTemp from pumphistory ended "+yt+"m ago; canceling temp",u.setTempBasal(0,0,i,ze,t)}var xt=o(-a.activity*Bt*5,2),St=o(6*(Ye-xt));St<0&&(St=o(6*(et-xt)))<0&&(St=o(6*(e.long_avgdelta-xt)));var Dt=Ve,wt=(Dt=a.iob>0?o(Ve-a.iob*Bt):o(Ve-a.iob*Math.min(Bt,N)))+St;if(void 0===wt||isNaN(wt))return ze.error="Error: could not calculate eventualBG. Sensitivity: "+Bt+" Deviation: "+St,ze;var Gt,Tt,Ct=function(e,t,a){return o(a+(e-t)/24,1)}(at,wt,xt);ze={temp:"absolute",bg:Ve,tick:Je,eventualBG:wt,insulinReq:0,reservoir:d,deliverAt:Ne,sensitivityRatio,CR:o(H,1),TDD:he,insulin:ge,current_target:at,insulinForManualBolus:G,manualBolusErrorString:0,minDelta:Ye,expectedDelta:Ct,minGuardBG:Tt,minPredBG:Gt,threshold:n(T,i)};var Ut=[],Ot=[],At=[],Rt=[];Ut.push(Ve),Ot.push(Ve),Rt.push(Ve),At.push(Ve);var It=function(e,t,a,r,o,i,s,l){if(!t)return console.error("SMB disabled (!microBolusAllowed)"),!1;if(!e.allowSMB_with_high_temptarget&&e.temptargetSet&&o>100)return console.error("SMB disabled due to high temptarget of "+o),!1;if(!0===a.bwFound&&!1===e.A52_risk_enable)return console.error("SMB disabled due to Bolus Wizard activity in the last 6 hours."),!1;if(400==r)return console.error("Invalid CGM (HIGH). SMBs disabled."),!1;if(s.smbIsOff){if(!s.smbIsAlwaysOff)return console.error("SMBs are disabled by profile override"),!1;{let e=l.getHours();if(s.end<s.start&&e<24&&e>s.start&&(s.end+=24),e>=s.start&&e<=s.end)return console.error("SMBs are disabled by profile override"),!1;if(s.end<s.start&&e<s.end)return console.error("SMBs are disabled by profile override"),!1}}return!0===e.enableSMB_always?(a.bwFound?console.error("Warning: SMB enabled within 6h of using Bolus Wizard: be sure to easy bolus 30s before using Bolus Wizard"):console.error("SMB enabled due to enableSMB_always"),!0):!0===e.enableSMB_with_COB&&a.mealCOB?(a.bwCarbs?console.error("Warning: SMB enabled with Bolus Wizard carbs: be sure to easy bolus 30s before using Bolus Wizard"):console.error("SMB enabled for COB of "+a.mealCOB),!0):!0===e.enableSMB_after_carbs&&a.carbs?(a.bwCarbs?console.error("Warning: SMB enabled with Bolus Wizard carbs: be sure to easy bolus 30s before using Bolus Wizard"):console.error("SMB enabled for 6h after carb entry"),!0):!0===e.enableSMB_with_temptarget&&e.temptargetSet&&o<100?(a.bwFound?console.error("Warning: SMB enabled within 6h of using Bolus Wizard: be sure to easy bolus 30s before using Bolus Wizard"):console.error("SMB enabled for temptarget of "+n(o,e)),!0):!0===e.enableSMB_high_bg&&null!==i&&r>=i?(console.error("Checking BG to see if High for SMB enablement."),console.error("Current BG",r," | High BG ",i),a.bwFound?console.error("Warning: High BG SMB enabled within 6h of using Bolus Wizard: be sure to easy bolus 30s before using Bolus Wizard"):console.error("High BG detected. Enabling SMB."),!0):(console.error("SMB disabled (no enableSMB preferences active or no condition satisfied)"),!1)}(i,m,l,Ve,at,nt,v,c),Ft=i.enableUAM,jt=0,Pt=0;jt=o(Ye-xt,1);var Et=o(Ye-xt,1);csf=Bt/H,console.error("profile.sens:"+n(N,i)+", sens:"+n(Bt,i)+", CSF:"+o(csf,1));var qt=o(30*csf*5/60,1);jt>qt&&(console.error("Limiting carb impact from "+jt+" to "+qt+"mg/dL/5m (30g/h)"),jt=qt);var Wt=3;sensitivityRatio&&(Wt/=sensitivityRatio);var kt=Wt;if(l.carbs){Wt=Math.max(Wt,l.mealCOB/20);var Lt=o((new Date($e).getTime()-l.lastCarbTime)/6e4),zt=(l.carbs-l.mealCOB)/l.carbs;kt=o(kt=Wt+1.5*Lt/60,1),console.error("Last carbs "+Lt+" minutes ago; remainingCATime:"+kt+"hours; "+o(100*zt,1)+"% carbs absorbed")}var Nt=Math.max(0,jt/5*60*kt/2)/csf,Ht=90,Zt=1;i.remainingCarbsCap&&(Ht=Math.min(90,i.remainingCarbsCap)),i.remainingCarbsFraction&&(Zt=Math.min(1,i.remainingCarbsFraction));var $t=1-Zt,Jt=Math.max(0,l.mealCOB-Nt-l.carbs*$t),Kt=(Jt=Math.min(Ht,Jt))*csf*5/60/(kt/2),Qt=o(l.slopeFromMaxDeviation,2),Vt=o(l.slopeFromMinDeviation,2),Xt=Math.min(Qt,-Vt/3);Pt=0===jt?0:Math.min(60*kt/5/2,Math.max(0,l.mealCOB*csf/jt)),console.error("Carb Impact:"+jt+"mg/dL per 5m; CI Duration:"+o(5*Pt/60*2,1)+"hours; remaining CI ("+kt/2+"h peak):"+o(Kt,1)+"mg/dL per 5m");var Yt,ea,ta,aa,ra=999,oa=999,na=999,ia=999,sa=999,la=999,ua=999,ma=wt,da=Ve,ca=Ve,ga=0,ha=[],pa=[];try{Mt.forEach((function(e){var t=o(-e.activity*Bt*5,2),a=o(-e.iobWithZeroTemp.activity*Bt*5,2),r=Dt,n=jt*(1-Math.min(1,Ot.length/12));if(!0===(w&&!Re))ma=Ot[Ot.length-1]+o(-e.activity*(1800/(P*fe*Math.log(Math.max(Ot[Ot.length-1],39)/Oe+1)))*5,2)+n,r=Rt[Rt.length-1]+o(-e.iobWithZeroTemp.activity*(1800/(P*fe*Math.log(Math.max(Rt[Rt.length-1],39)/Oe+1)))*5,2),console.log("Dynamic ISF (Logarithmic Formula) )adjusted predictions for IOB and ZT: IOBpredBG: "+o(ma,2)+" , ZTpredBG: "+o(r,2));else ma=Ot[Ot.length-1]+t+n,r=Rt[Rt.length-1]+a;var i=Math.max(0,Math.max(0,jt)*(1-Ut.length/Math.max(2*Pt,1))),s=Math.min(Ut.length,12*kt-Ut.length),l=Math.max(0,s/(kt/2*12)*Kt);i+l,ha.push(o(l,0)),pa.push(o(i,0)),COBpredBG=Ut[Ut.length-1]+t+Math.min(0,n)+i+l;var u=Math.max(0,Et+At.length*Xt),m=Math.max(0,Et*(1-At.length/Math.max(36,1))),d=Math.min(u,m);if(d>0&&(ga=o(5*(At.length+1)/60,1)),!0===(w&&!Re))UAMpredBG=At[At.length-1]+o(-e.activity*(1800/(P*fe*Math.log(Math.max(At[At.length-1],39)/Oe+1)))*5,2)+Math.min(0,n)+d,console.log("Dynamic ISF (Logarithmic Formula) adjusted prediction for UAM: UAMpredBG: "+o(UAMpredBG,2));else UAMpredBG=At[At.length-1]+t+Math.min(0,n)+d;Ot.length<48&&Ot.push(ma),Ut.length<48&&Ut.push(COBpredBG),At.length<48&&At.push(UAMpredBG),Rt.length<48&&Rt.push(r),COBpredBG<ia&&(ia=o(COBpredBG)),UAMpredBG<sa&&(sa=o(UAMpredBG)),ma<la&&(la=o(ma)),r<ua&&(ua=o(r));Ot.length>18&&ma<ra&&(ra=o(ma)),ma>da&&(da=ma),(Pt||Kt>0)&&Ut.length>18&&COBpredBG<oa&&(oa=o(COBpredBG)),(Pt||Kt>0)&&COBpredBG>da&&(ca=COBpredBG),Ft&&At.length>12&&UAMpredBG<na&&(na=o(UAMpredBG)),Ft&&UAMpredBG>da&&UAMpredBG}))}catch(e){console.error("Problem with iobArray.  Optional feature Advanced Meal Assist disabled")}l.mealCOB&&(console.error("predCIs (mg/dL/5m):"+pa.join(" ")),console.error("remainingCIs:      "+ha.join(" "))),ze.predBGs={},Ot.forEach((function(e,t,a){a[t]=o(Math.min(401,Math.max(39,e)))}));for(var va=Ot.length-1;va>12&&Ot[va-1]===Ot[va];va--)Ot.pop();for(ze.predBGs.IOB=Ot,ea=o(Ot[Ot.length-1]),Rt.forEach((function(e,t,a){a[t]=o(Math.min(401,Math.max(39,e)))})),va=Rt.length-1;va>6&&!(Rt[va-1]>=Rt[va]||Rt[va]<=at);va--)Rt.pop();if(ze.predBGs.ZT=Rt,o(Rt[Rt.length-1]),l.mealCOB>0&&(jt>0||Kt>0)){for(Ut.forEach((function(e,t,a){a[t]=o(Math.min(1500,Math.max(39,e)))})),va=Ut.length-1;va>12&&Ut[va-1]===Ut[va];va--)Ut.pop();ze.predBGs.COB=Ut,ta=o(Ut[Ut.length-1]),wt=Math.max(wt,o(Ut[Ut.length-1])),console.error("COBpredBG: "+o(Ut[Ut.length-1]))}if(jt>0||Kt>0){if(Ft){for(At.forEach((function(e,t,a){a[t]=o(Math.min(401,Math.max(39,e)))})),va=At.length-1;va>12&&At[va-1]===At[va];va--)At.pop();ze.predBGs.UAM=At,aa=o(At[At.length-1]),At[At.length-1]&&(wt=Math.max(wt,o(At[At.length-1])))}ze.eventualBG=wt}console.error("UAM Impact:"+Et+"mg/dL per 5m; UAM Duration:"+ga+"hours"),ra=Math.max(39,ra),oa=Math.max(39,oa),na=Math.max(39,na),Gt=o(ra);var fa=l.mealCOB/l.carbs;Yt=o(na<999&&oa<999?(1-fa)*UAMpredBG+fa*COBpredBG:oa<999?(ma+COBpredBG)/2:na<999?(ma+UAMpredBG)/2:ma),ua>Yt&&(Yt=ua),Tt=o(Tt=Pt||Kt>0?Ft?fa*ia+(1-fa)*sa:ia:Ft?sa:la);var Ba=na;if(ua<T)Ba=(na+ua)/2;else if(ua<at){var ba=(ua-T)/(at-T);Ba=(na+(na*ba+ua*(1-ba)))/2}else ua>na&&(Ba=(na+ua)/2);if(Ba=o(Ba),l.carbs)if(!Ft&&oa<999)Gt=o(Math.max(ra,oa));else if(oa<999){var Ma=fa*oa+(1-fa)*Ba;Gt=o(Math.max(ra,oa,Ma))}else Gt=Ft?Ba:Tt;else Ft&&(Gt=o(Math.max(ra,Ba)));Gt=Math.min(Gt,Yt),process.stderr.write("minPredBG: "+Gt+" minIOBPredBG: "+ra+" minZTGuardBG: "+ua),oa<999&&process.stderr.write(" minCOBPredBG: "+oa),na<999&&process.stderr.write(" minUAMPredBG: "+na),console.error(" avgPredBG:"+Yt+" COB/Carbs:"+l.mealCOB+"/"+l.carbs),ca>Ve&&(Gt=Math.min(Gt,ca)),ze.COB=l.mealCOB,ze.IOB=a.iob,ze.BGI=n(xt,i),ze.deviation=n(St,i),ze.ISF=n(Bt,i),ze.CR=o(H,1),ze.target_bg=n(at,i),ze.TDD=o(he,2),ze.current_target=o(at,0);var _a=ze.CR;qe!=ze.CR&&(_a=qe+"→"+ze.CR),ze.reason=ft+", COB: "+ze.COB+", Dev: "+ze.deviation+", BGI: "+ze.BGI+", CR: "+_a+", Target: "+ct+", minPredBG: "+n(Gt,i)+", minGuardBG: "+n(Tt,i)+", IOBpredBG: "+n(ea,i),ta>0&&(ze.reason+=", COBpredBG: "+n(ta,i)),aa>0&&(ze.reason+=", UAMpredBG: "+n(aa,i)),ze.reason+=F,ze.reason+="; ",It||(ze.reason+="SMB Av. ");var ya=Dt;ya<40&&(ya=Math.min(Tt,ya));var xa,Sa=T-ya,Da=240,wa=240;if(l.mealCOB>0&&(jt>0||Kt>0)){for(va=0;va<Ut.length;va++)if(Ut[va]<rt){Da=5*va;break}for(va=0;va<Ut.length;va++)if(Ut[va]<T){wa=5*va;break}}else{for(va=0;va<Ot.length;va++)if(Ot[va]<rt){Da=5*va;break}for(va=0;va<Ot.length;va++)if(Ot[va]<T){wa=5*va;break}}It&&Tt<T&&(console.error("minGuardBG "+n(Tt,i)+" projected below "+n(T,i)+" - disabling SMB"),ze.manualBolusErrorString=1,ze.minGuardBG=Tt,ze.insulinForManualBolus=o((ze.eventualBG-ze.target_bg)/Bt,2),It=!1),void 0===i.maxDelta_bg_threshold&&(xa=.2),void 0!==i.maxDelta_bg_threshold&&(xa=Math.min(i.maxDelta_bg_threshold,.4)),tt>xa*Ve&&(console.error("maxDelta "+n(tt,i)+" > "+100*xa+"% of BG "+n(Ve,i)+" - disabling SMB"),ze.reason+="maxDelta "+n(tt,i)+" > "+100*xa+"% of BG "+n(Ve,i)+" - SMB disabled!, ",It=!1),console.error("BG projected to remain above "+n(rt,i)+" for "+Da+"minutes"),(wa<240||Da<60)&&console.error("BG projected to remain above "+n(T,i)+" for "+wa+"minutes");var Ga=wa,Ta=i.current_basal*z*Bt*Ga/60,Ca=Math.max(0,l.mealCOB-.25*l.carbs),Ua=(Sa-Ta)/csf-Ca;Ta=o(Ta),Ua=o(Ua),console.error("naive_eventualBG:",Dt,"bgUndershoot:",Sa,"zeroTempDuration:",Ga,"zeroTempEffect:",Ta,"carbsReq:",Ua),"Could not parse clock data"==l.reason?console.error("carbsReq unknown: Could not parse clock data"):Ua>=i.carbsReqThreshold&&wa<=45&&(ze.carbsReq=Ua,ze.reason+=Ua+" extra kh krävs inom "+wa+"m; ");var Oa=0;if(Ve<T&&a.iob<-i.current_basal*z*20/60&&Ye>0&&Ye>Ct)ze.reason+="IOB "+a.iob+" < "+o(-i.current_basal*z*20/60,2),ze.reason+=" and minDelta "+n(Ye,i)+" > expectedDelta "+n(Ct,i)+"; ";else if(Ve<T||Tt<T)return ze.reason+="minGuardBG "+n(Tt,i)+"<"+n(T,i),Sa=at-Tt,Tt<T&&(ze.manualBolusErrorString=2,ze.minGuardBG=Tt),ze.insulinForManualBolus=o((wt-at)/Bt,2),Oa=o(60*(Sa/Bt)/i.current_basal*z),Oa=30*o(Oa/30),Oa=Math.min(120,Math.max(30,Oa)),u.setTempBasal(0,Oa,i,ze,t);if(i.skip_neutral_temps&&ze.deliverAt.getMinutes()>=55)return ze.reason+="; Canceling temp at "+ze.deliverAt.getMinutes()+"m past the hour. ",u.setTempBasal(0,0,i,ze,t);var Aa=0,Ra=Ze,Ia=0;if(wt<rt){if(ze.reason+="Prognos BG "+n(wt,i)+" < "+n(rt,i),Ye>Ct&&Ye>0&&!Ua)return Dt<40?(ze.reason+=", naive_eventualBG < 40. ",u.setTempBasal(0,30,i,ze,t)):(e.delta>Ye?ze.reason+=", but Delta "+n(Je,i)+" > expectedDelta "+n(Ct,i):ze.reason+=", but Min. Delta "+Ye.toFixed(2)+" > Exp. Delta "+n(Ct,i),t.duration>15&&r(Ze,i)===r(t.rate,i)?(ze.reason+=", temp "+t.rate+" ~ req "+Ze+"E/h. ",ze):(ze.reason+="; setting current basal of "+Ze+" as temp. ",u.setTempBasal(Ze,30,i,ze,t)));Aa=o(Aa=2*Math.min(0,(wt-at)/Bt),2);var Fa=Math.min(0,(Dt-at)/Bt);if(Fa=o(Fa,2),Ye<0&&Ye>Ct)Aa=o(Aa*(Ye/Ct),2);Ra=r(Ra=Ze+2*Aa,i),Ia=t.duration*(t.rate-Ze)/60;var ja=Math.min(Aa,Fa);if(console.log("naiveInsulinReq:"+Fa),Ia<ja-.3*Ze)return ze.reason+=", "+t.duration+"m@"+t.rate.toFixed(2)+" is a lot less than needed. ",u.setTempBasal(Ra,30,i,ze,t);if(void 0!==t.rate&&t.duration>5&&Ra>=.8*t.rate)return ze.reason+=", temp "+t.rate+" ~< req "+Ra+"E/h ",ze;if(Ra<=0){if((Oa=o(60*((Sa=at-Dt)/Bt)/i.current_basal*z))<0?Oa=0:(Oa=30*o(Oa/30),Oa=Math.min(120,Math.max(0,Oa))),Oa>0)return ze.reason+=", setting "+Oa+"m zero temp. ",u.setTempBasal(Ra,Oa,i,ze,t)}else ze.reason+=", setting "+Ra+"E/h. ";return u.setTempBasal(Ra,30,i,ze,t)}if(Ye<Ct&&(ze.minDelta=Ye,ze.expectedDelta=Ct,(Ct-Ye>=2||Ct+-1*Ye>=2)&&(ze.manualBolusErrorString=Ye>=0&&Ct>0?3:Ye<0&&Ct<=0||Ye<0&&Ct>=0?4:5),ze.insulinForManualBolus=o((ze.eventualBG-ze.target_bg)/Bt,2),!m||!It))return e.delta<Ye?ze.reason+="Prognos BG "+n(wt,i)+" > "+n(rt,i)+" but Delta "+n(Je,i)+" < Exp. Delta "+n(Ct,i):ze.reason+="Prognos BG "+n(wt,i)+" > "+n(rt,i)+" but Min. Delta "+Ye.toFixed(2)+" < Exp. Delta "+n(Ct,i),t.duration>15&&r(Ze,i)===r(t.rate,i)?(ze.reason+=", temp "+t.rate+" ~ req "+Ze+"E/h. ",ze):(ze.reason+="; setting current basal of "+Ze+" as temp. ",u.setTempBasal(Ze,30,i,ze,t));if(Math.min(wt,Gt)<ot&&(Gt<rt&&wt>rt&&(ze.manualBolusErrorString=6,ze.insulinForManualBolus=o((ze.eventualBG-ze.target_bg)/Bt,2),ze.minPredBG=Gt),!m||!It))return ze.reason+=n(wt,i)+"-"+n(Gt,i)+" in range: no temp required",t.duration>15&&r(Ze,i)===r(t.rate,i)?(ze.reason+=", temp "+t.rate+" ~ req "+Ze+"E/h. ",ze):(ze.reason+="; setting current basal of "+Ze+" as temp. ",u.setTempBasal(Ze,30,i,ze,t));if(wt>=ot&&(ze.reason+="Prognos BG "+n(wt,i)+" >= "+n(ot,i)+", ",wt>ot&&(ze.insulinForManualBolus=o((wt-at)/Bt,2))),a.iob>it)return ze.reason+="IOB "+o(a.iob,2)+" > max_iob "+it,t.duration>15&&r(Ze,i)===r(t.rate,i)?(ze.reason+=", temp "+t.rate+" ~ req "+Ze+"E/h. ",ze):(ze.reason+="; setting current basal of "+Ze+" as temp. ",u.setTempBasal(Ze,30,i,ze,t));Aa=o((Math.min(Gt,wt)-at)/Bt,2),G=o((wt-at)/Bt,2),Aa>it-a.iob?(console.error("SMB limited by maxIOB: "+it-a.iob+" (. Insulinbehov: "+Aa+" E)"),ze.reason+="max_iob "+it+", ",Aa=it-a.iob):console.error("SMB not limited by maxIOB ( Insulinbehov: "+Aa+" E)."),G>it-a.iob?(console.error("Ev. Bolus limited by maxIOB: "+it-a.iob+" (. insulinForManualBolus: "+G+" E)"),ze.reason+="max_iob "+it+", "):console.error("Ev. Bolus would not be limited by maxIOB ( insulinForManualBolus: "+G+" E)."),Ra=r(Ra=Ze+2*Aa,i),Aa=o(Aa,3),ze.insulinReq=Aa;var Pa=o((new Date($e).getTime()-a.lastBolusTime)/6e4,1);if(m&&It&&Ve>T){var Ea=30;void 0!==i.maxSMBBasalMinutes&&(Ea=i.maxSMBBasalMinutes);var qa=30;void 0!==i.maxUAMSMBBasalMinutes&&(qa=i.maxUAMSMBBasalMinutes),v.useOverride&&M&&S!==Ea&&(console.error("SMB Max Minutes - setting overriden from "+Ea+" to "+S),Ea=S),v.useOverride&&M&&D!==qa&&(console.error("UAM Max Minutes - setting overriden from "+qa+" to "+D),qa=D);var Wa=o(l.mealCOB/H,3),ka=0;void 0===Ea?(ka=o(i.current_basal*z*30/60,1),console.error("smbMinutesSetting undefined: defaulting to 30m"),Aa>ka&&console.error("SMB limited by maxBolus: "+ka+" ( "+Aa+" E)")):a.iob>Wa&&a.iob>0?(console.error("IOB"+a.iob+"> COB"+l.mealCOB+"; mealInsulinReq ="+Wa),qa?(console.error("maxUAMSMBBasalMinutes: "+qa+", profile.current_basal: "+i.current_basal*z),ka=o(i.current_basal*z*qa/60,1)):(console.error("maxUAMSMBBasalMinutes undefined: defaulting to 30m"),ka=o(i.current_basal*z*30/60,1)),Aa>ka?console.error("SMB limited by maxUAMSMBBasalMinutes [ "+qa+"m ]: "+ka+"E ( "+Aa+"E )"):console.error("SMB is not limited by maxUAMSMBBasalMinutes. ( Insulinbehov: "+Aa+"E )")):(console.error(".maxSMBBasalMinutes: "+Ea+", profile.current_basal: "+i.current_basal*z),Aa>(ka=o(i.current_basal*Ea/60,1))?console.error("SMB limited by maxSMBBasalMinutes: "+Ea+"m ]: "+ka+"E ( Insulinbehov: "+Aa+"E )"):console.error("SMB is not limited by maxSMBBasalMinutes. ( Insulinbehov: "+Aa+"E )"));var La=i.bolus_increment,za=1/La,Na=i.smb_delivery_ratio;Na>.5&&console.error("SMB Delivery Ratio increased from default 0.5 to "+o(Na,2));var Ha=Math.min(Aa*Na,ka);Ha=Math.floor(Ha*za)/za,Oa=o(60*((at-(Dt+ra)/2)/Bt)/i.current_basal*z),Aa>0&&Ha<La&&(Oa=0);var Za=0;Oa<=0?Oa=0:Oa>=30?(Oa=30*o(Oa/30),Oa=Math.min(60,Math.max(0,Oa))):(Za=o(Ze*Oa/30,2),Oa=30),ze.reason+=" Insulinbehov "+Aa,Ha>=ka&&(ze.reason+="; maxBolus "+ka),Oa>0&&(ze.reason+="; setting "+Oa+"m low temp of "+Za+"E/h"),ze.reason+=". ";var $a=3;i.SMBInterval&&($a=Math.min(10,Math.max(1,i.SMBInterval)));var Ja=o($a-Pa,0),Ka=o(60*($a-Pa),0)%60;if(console.error("naive_eventualBG "+Dt+","+Oa+"m "+Za+"E/h temp needed; last bolus "+Pa+"m ago; maxBolus: "+ka),Pa>$a?Ha>0&&(ze.units=Ha,ze.reason+="Gav mikrobolus: "+Ha+"E. "):ze.reason+="Waiting "+Ja+"m "+Ka+"s to microbolus again. ",Oa>0)return ze.rate=Za,ze.duration=Oa,ze}var Qa=u.getMaxSafeBasal(i);return 400==Ve?u.setTempBasal(i.current_basal,30,i,ze,t):(Ra>Qa&&(ze.reason+="adj. req. rate: "+Ra+" to maxSafeBasal: "+o(Qa,2)+", ",Ra=r(Qa,i)),(Ia=t.duration*(t.rate-Ze)/60)>=2*Aa?(ze.reason+=t.duration+"m@"+t.rate.toFixed(2)+" > 2 * Insulinbehov. Setting temp basal of "+Ra+"E/h. ",u.setTempBasal(Ra,30,i,ze,t)):void 0===t.duration||0===t.duration?(ze.reason+="no temp, setting "+Ra+"E/h. ",u.setTempBasal(Ra,30,i,ze,t)):t.duration>5&&r(Ra,i)<=r(t.rate,i)?(ze.reason+="temp "+t.rate+" >~ req "+Ra+"E/h. ",ze):(ze.reason+="temp "+t.rate+"<"+Ra+"E/h. ",u.setTempBasal(Ra,30,i,ze,t)))}},6880:(e,t,a)=>{var r=a(6654);e.exports=function(e,t){var a=20;void 0!==t&&"string"==typeof t.model&&(r(t.model,"54")||r(t.model,"23"))&&(a=40);return e<1?Math.round(e*a)/a:e<10?Math.round(20*e)/20:Math.round(10*e)/10}},2705:(e,t,a)=>{var r=a(5639).Symbol;e.exports=r},9932:e=>{e.exports=function(e,t){for(var a=-1,r=null==e?0:e.length,o=Array(r);++a<r;)o[a]=t(e[a],a,e);return o}},9750:e=>{e.exports=function(e,t,a){return e==e&&(void 0!==a&&(e=e<=a?e:a),void 0!==t&&(e=e>=t?e:t)),e}},4239:(e,t,a)=>{var r=a(2705),o=a(9607),n=a(2333),i=r?r.toStringTag:void 0;e.exports=function(e){return null==e?void 0===e?"[object Undefined]":"[object Null]":i&&i in Object(e)?o(e):n(e)}},531:(e,t,a)=>{var r=a(2705),o=a(9932),n=a(1469),i=a(3448),s=r?r.prototype:void 0,l=s?s.toString:void 0;e.exports=function e(t){if("string"==typeof t)return t;if(n(t))return o(t,e)+"";if(i(t))return l?l.call(t):"";var a=t+"";return"0"==a&&1/t==-Infinity?"-0":a}},7561:(e,t,a)=>{var r=a(7990),o=/^\s+/;e.exports=function(e){return e?e.slice(0,r(e)+1).replace(o,""):e}},1957:(e,t,a)=>{var r="object"==typeof a.g&&a.g&&a.g.Object===Object&&a.g;e.exports=r},9607:(e,t,a)=>{var r=a(2705),o=Object.prototype,n=o.hasOwnProperty,i=o.toString,s=r?r.toStringTag:void 0;e.exports=function(e){var t=n.call(e,s),a=e[s];try{e[s]=void 0;var r=!0}catch(e){}var o=i.call(e);return r&&(t?e[s]=a:delete e[s]),o}},2333:e=>{var t=Object.prototype.toString;e.exports=function(e){return t.call(e)}},5639:(e,t,a)=>{var r=a(1957),o="object"==typeof self&&self&&self.Object===Object&&self,n=r||o||Function("return this")();e.exports=n},7990:e=>{var t=/\s/;e.exports=function(e){for(var a=e.length;a--&&t.test(e.charAt(a)););return a}},6654:(e,t,a)=>{var r=a(9750),o=a(531),n=a(554),i=a(9833);e.exports=function(e,t,a){e=i(e),t=o(t);var s=e.length,l=a=void 0===a?s:r(n(a),0,s);return(a-=t.length)>=0&&e.slice(a,l)==t}},1469:e=>{var t=Array.isArray;e.exports=t},3218:e=>{e.exports=function(e){var t=typeof e;return null!=e&&("object"==t||"function"==t)}},7005:e=>{e.exports=function(e){return null!=e&&"object"==typeof e}},3448:(e,t,a)=>{var r=a(4239),o=a(7005);e.exports=function(e){return"symbol"==typeof e||o(e)&&"[object Symbol]"==r(e)}},8601:(e,t,a)=>{var r=a(4841),o=1/0;e.exports=function(e){return e?(e=r(e))===o||e===-1/0?17976931348623157e292*(e<0?-1:1):e==e?e:0:0===e?e:0}},554:(e,t,a)=>{var r=a(8601);e.exports=function(e){var t=r(e),a=t%1;return t==t?a?t-a:t:0}},4841:(e,t,a)=>{var r=a(7561),o=a(3218),n=a(3448),i=/^[-+]0x[0-9a-f]+$/i,s=/^0b[01]+$/i,l=/^0o[0-7]+$/i,u=parseInt;e.exports=function(e){if("number"==typeof e)return e;if(n(e))return NaN;if(o(e)){var t="function"==typeof e.valueOf?e.valueOf():e;e=o(t)?t+"":t}if("string"!=typeof e)return 0===e?e:+e;e=r(e);var a=s.test(e);return a||l.test(e)?u(e.slice(2),a?2:8):i.test(e)?NaN:+e}},9833:(e,t,a)=>{var r=a(531);e.exports=function(e){return null==e?"":r(e)}}},t={};function a(r){var o=t[r];if(void 0!==o)return o.exports;var n=t[r]={exports:{}};return e[r](n,n.exports,a),n.exports}a.g=function(){if("object"==typeof globalThis)return globalThis;try{return this||new Function("return this")()}catch(e){if("object"==typeof window)return window}}();var r=a(5546);freeaps_determineBasal=r})();
