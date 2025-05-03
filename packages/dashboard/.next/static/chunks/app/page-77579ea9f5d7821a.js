(self.webpackChunk_N_E=self.webpackChunk_N_E||[]).push([[931],{4287:function(e,r,t){"use strict";t.d(r,{Z:function(){return j}});var i=t(5906),a=t(7198),s=t(7653),n=t(794),o=t(7650),l=t(2659),c=t(2840),u=t(2042),d=t(1599),f=t(5245),h=t(2389);function m(e){return(0,h.ZP)("MuiCircularProgress",e)}(0,f.Z)("MuiCircularProgress",["root","determinate","indeterminate","colorPrimary","colorSecondary","svg","circle","circleDeterminate","circleIndeterminate","circleDisableShrink"]);var v=t(7573);let k=["className","color","disableShrink","size","style","thickness","value","variant"],p=e=>e,x,g,Z,y,P=(0,l.F4)(x||(x=p`
  0% {
    transform: rotate(0deg);
  }

  100% {
    transform: rotate(360deg);
  }
`)),b=(0,l.F4)(g||(g=p`
  0% {
    stroke-dasharray: 1px, 200px;
    stroke-dashoffset: 0;
  }

  50% {
    stroke-dasharray: 100px, 200px;
    stroke-dashoffset: -15px;
  }

  100% {
    stroke-dasharray: 100px, 200px;
    stroke-dashoffset: -125px;
  }
`)),C=e=>{let{classes:r,variant:t,color:i,disableShrink:a}=e,s={root:["root",t,`color${(0,c.Z)(i)}`],svg:["svg"],circle:["circle",`circle${(0,c.Z)(t)}`,a&&"circleDisableShrink"]};return(0,o.Z)(s,m,r)},S=(0,d.ZP)("span",{name:"MuiCircularProgress",slot:"Root",overridesResolver:(e,r)=>{let{ownerState:t}=e;return[r.root,r[t.variant],r[`color${(0,c.Z)(t.color)}`]]}})(({ownerState:e,theme:r})=>(0,a.Z)({display:"inline-block"},"determinate"===e.variant&&{transition:r.transitions.create("transform")},"inherit"!==e.color&&{color:(r.vars||r).palette[e.color].main}),({ownerState:e})=>"indeterminate"===e.variant&&(0,l.iv)(Z||(Z=p`
      animation: ${0} 1.4s linear infinite;
    `),P)),w=(0,d.ZP)("svg",{name:"MuiCircularProgress",slot:"Svg",overridesResolver:(e,r)=>r.svg})({display:"block"}),D=(0,d.ZP)("circle",{name:"MuiCircularProgress",slot:"Circle",overridesResolver:(e,r)=>{let{ownerState:t}=e;return[r.circle,r[`circle${(0,c.Z)(t.variant)}`],t.disableShrink&&r.circleDisableShrink]}})(({ownerState:e,theme:r})=>(0,a.Z)({stroke:"currentColor"},"determinate"===e.variant&&{transition:r.transitions.create("stroke-dashoffset")},"indeterminate"===e.variant&&{strokeDasharray:"80px, 200px",strokeDashoffset:0}),({ownerState:e})=>"indeterminate"===e.variant&&!e.disableShrink&&(0,l.iv)(y||(y=p`
      animation: ${0} 1.4s ease-in-out infinite;
    `),b)),M=s.forwardRef(function(e,r){let t=(0,u.i)({props:e,name:"MuiCircularProgress"}),{className:s,color:o="primary",disableShrink:l=!1,size:c=40,style:d,thickness:f=3.6,value:h=0,variant:m="indeterminate"}=t,p=(0,i.Z)(t,k),x=(0,a.Z)({},t,{color:o,disableShrink:l,size:c,thickness:f,value:h,variant:m}),g=C(x),Z={},y={},P={};if("determinate"===m){let e=2*Math.PI*((44-f)/2);Z.strokeDasharray=e.toFixed(3),P["aria-valuenow"]=Math.round(h),Z.strokeDashoffset=`${((100-h)/100*e).toFixed(3)}px`,y.transform="rotate(-90deg)"}return(0,v.jsx)(S,(0,a.Z)({className:(0,n.Z)(g.root,s),style:(0,a.Z)({width:c,height:c},y,d),ownerState:x,ref:r,role:"progressbar"},P,p,{children:(0,v.jsx)(w,{className:g.svg,ownerState:x,viewBox:"22 22 44 44",children:(0,v.jsx)(D,{className:g.circle,style:Z,ownerState:x,cx:44,cy:44,r:(44-f)/2,fill:"none",strokeWidth:f})})}))});var j=M},6248:function(e,r,t){Promise.resolve().then(t.bind(t,6633))},6633:function(e,r,t){"use strict";t.r(r),t.d(r,{default:function(){return c}});var i=t(7573),a=t(7653),s=t(2859),n=t(6190),o=t(4287),l=t(6718);function c(){let e=(0,s.useRouter)();return(0,a.useEffect)(()=>{let r=localStorage.getItem("token");r?e.push("/dashboard"):e.push("/login")},[e]),(0,i.jsxs)(n.Z,{sx:{display:"flex",flexDirection:"column",alignItems:"center",justifyContent:"center",height:"100vh"},children:[(0,i.jsx)(o.Z,{size:60,thickness:4}),(0,i.jsx)(l.Z,{variant:"h5",sx:{mt:4},children:"Loading MeowCoin Platform..."})]})}},2859:function(e,r,t){e.exports=t(7699)}},function(e){e.O(0,[331,317,293,53,744],function(){return e(e.s=6248)}),_N_E=e.O()}]);