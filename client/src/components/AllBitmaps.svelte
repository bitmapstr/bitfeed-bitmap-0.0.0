<script>
        export async function GetAllBitmaps() {
        let insArray = [];
            
            const inscriptions = "https://api.hiro.so/ordinals/v1/inscriptions"
            const insResponse = await fetch(inscriptions)
            const all = await insResponse.json()
            const allresults = await all
            console.log("Total: " + all.total)
            //const allIDs = allresults.results[0].id
           // console.log(allIDs)

            for (let i = 0; i < 5; i++) {
                const id = allresults.results[i].id
                console.log(allresults.results[i])
                const inscriptionid ="https://api.hiro.so/ordinals/v1/inscriptions/" + id
                const content = await fetch(inscriptionid + "/content")
                const ins = await content.text()
                //console.log("content:" + ins)

            }

            const id = "ad48cd9f181f4f7d689f0881f3daf88d150d8354ea5ff7e5962c423eba2c01dai0"
            const inscriptionid ="https://api.hiro.so/ordinals/v1/inscriptions/" + id
            const content = await fetch(inscriptionid + "/content")
            const ins = await content.text()
            console.log(ins)

        //     for (let i = 0; i < response.total; i++) {
        //         //const insID = res.list[i].inscriptionId;
        //         //const hiro ="https://api.hiro.so/ordinals/v1/inscriptions/" + insID;
        //         //const content = await fetch(hiro + "/content");
        //         // const ins = await content.text();
        //         // const inscriptionParts = ins.split(".");
        //         // const bitmapNum = inscriptionParts[0];
        //         // const bitmapText = "bitmap";
        //         // if (ins.includes(bitmapText)) {
        //         //     insArray.push(bitmapNum);
        //         // }
        //         // console.log("Content: " + ins)
        //         // console.log("InsID: " + insID)
     
    }

</script>

<button on:click={GetAllBitmaps}> get em all </button>