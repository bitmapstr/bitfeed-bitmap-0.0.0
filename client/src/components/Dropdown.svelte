<script>
	import GetMyBitmaps from "./ConnectWallet.svelte"

	function getmybitmaps(){
		let bitmaps = new GetMyBitmaps()
		console.log(bitmaps)
		return [bitmaps]
		}

	function handleSubmit() {
		alert("submit alert");
	}
	$: bitmaps = bitmaps
	
	let selected;
	let bitmapNum = "";
	
</script>

<h2>My bitmaps</h2>
<form on:submit|preventDefault={handleSubmit}>

	<select bind:value={selected} on:change={() => (selected)}>
		
			{#await getmybitmaps}
			<p>...waiting for my bitmaps</p> 
			{:then data}
			{console.log("BITMAPS: " + data)}
			{#each data[0] as bitmap}
				<option value={bitmap}>{bitmap}</option>
			{/each}
			{/await}
		
	</select>
	
	<input bind:value={selected}  />
	<button disabled={!selected} type="submit"> Submit </button>

<p>selected bitmap {selected ? selected : "[waiting...]"}</p>
</form>

<style>
	input {
		display: block;
		width: 200px;
		max-width: 100%;
	}
</style>
