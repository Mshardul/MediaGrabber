// The oracle orb, ported from explore/orb.html.
// 24x24 outlines, one of each, so no two symbols in the orb are alike.
const SYMBOLS=[
 ['play','M7 4l13 8-13 8z',true],
 ['note','M12 18V3c2 4 7 3 6 9M12 18a3.5 3 0 1 1-7 0a3.5 3 0 1 1 7 0',false],
 ['beamed','M9 18V5l12-2v13M9 9l12-2M9 18a3 3 0 1 1-6 0a3 3 0 1 1 6 0M21 16a3 3 0 1 1-6 0a3 3 0 1 1 6 0',false],
 ['film','M3 5h18v14H3zM7 5v14M17 5v14M3 10h4M3 14h4M17 10h4M17 14h4',false],
 ['reel','M21 12a9 9 0 1 1-18 0a9 9 0 1 1 18 0M10 7.5a2 2 0 1 0 4 0a2 2 0 1 0-4 0M10 16.5a2 2 0 1 0 4 0a2 2 0 1 0-4 0M5.5 12a2 2 0 1 0 4 0a2 2 0 1 0-4 0M14.5 12a2 2 0 1 0 4 0a2 2 0 1 0-4 0',false],
 ['camcorder','M3 7h12v10H3zM15 10l6-3v10l-6-3',false],
 ['camera','M3 8h4l2-3h6l2 3h4v11H3zM15.5 13a3.5 3.5 0 1 1-7 0a3.5 3.5 0 1 1 7 0',false],
 ['mic','M9 6a3 3 0 0 1 6 0v6a3 3 0 0 1-6 0zM5 11a7 7 0 0 0 14 0M12 18v4M8 22h8',false],
 ['headphones','M4 15v-3a8 8 0 0 1 16 0v3M4 14h4v7H6a2 2 0 0 1-2-2zM20 14h-4v7h2a2 2 0 0 0 2-2z',false],
 ['picture','M3 4h18v16H3zM3 17l5-6 4 4 3-3 6 6M17 8.5a1.5 1.5 0 1 1-3 0a1.5 1.5 0 1 1 3 0',false],
 ['clapper','M3 10h18v10H3zM3 10l-1-4 17-4 1 4zM7 5l3 3M12 4l3 3',false],
 ['wave','M3 10v4M7 6v12M11 3v18M15 8v8M19 5v14M23 10v4',false],
 ['speaker','M3 9h4l6-5v16l-6-5H3zM16 9a4 4 0 0 1 0 6M19 6a8 8 0 0 1 0 12',false],
 ['tv','M3 7h18v13H3zM8 2l4 5 4-5',false],
 ['radio','M3 9h18v11H3zM6 9l12-6M10 14.5a2.5 2.5 0 1 1-5 0a2.5 2.5 0 1 1 5 0M14 13h4M14 16h4',false],
 ['vinyl','M21 12a9 9 0 1 1-18 0a9 9 0 1 1 18 0M15 12a3 3 0 1 1-6 0a3 3 0 1 1 6 0M6 12a6 6 0 0 1 6-6',false],
 ['broadcast','M14 12a2 2 0 1 1-4 0a2 2 0 1 1 4 0M8 8a6 6 0 0 0 0 8M16 8a6 6 0 0 1 0 8M5 5a10 10 0 0 0 0 14M19 5a10 10 0 0 1 0 14',false],
 ['captions','M3 5h18v14H3zM10 10a2.5 2.5 0 1 0 0 4M17 10a2.5 2.5 0 1 0 0 4',false],
 ['playlist','M3 6h12M3 11h12M3 16h7M16 13l6 4-6 4z',false],
 ['download','M12 3v12M7 10l5 5 5-5M4 21h16',false],
 ['link','M10 14a4 4 0 0 0 6 0l3-3a4 4 0 0 0-6-6l-1 1M14 10a4 4 0 0 0-6 0l-3 3a4 4 0 0 0 6 6l1-1',false],
 ['gamepad','M7 8h10a5 5 0 0 1 0 10l-3-3h-4l-3 3a5 5 0 0 1 0-10zM7 11v3M5.5 12.5h3M16 12h.1M18 14h.1',false],
 ['book','M12 6c-2-2-6-2-9-1v14c3-1 7-1 9 1c2-2 6-2 9-1V5c-3-1-7-1-9 1zM12 6v14',false],
 ['cassette','M3 6h18v12H3zM10 11a2 2 0 1 1-4 0a2 2 0 1 1 4 0M18 11a2 2 0 1 1-4 0a2 2 0 1 1 4 0M7 18l2-3h6l2 3',false]
].map(([name,d,solid])=>({name,path:new Path2D(d),solid}));
