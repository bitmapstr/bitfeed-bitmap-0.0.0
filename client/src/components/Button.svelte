<script>
	
	let buttonProps = {
	class:[$$restProps.class]
	}
</script>
	<button on:click,
			on:mouseover,
			on:mouseenter,
			on:mouseleave,
		{...buttonProps}>
			<slot/>
	</button>

<style>
	.primary{
		color:green;
	}
	.danger {
		color:red;
	}
	.sm {
		font-size:1em;
		padding:0.1em;
	}
	.lg {
		font-size:2em
	}
	button {
		color: #a5a5a5;
		outline: none;
		background: none;
		border-width: 1;
		padding: 0;
		border-radius: .5em;
		margin: 0;
		cursor: pointer;
}
</style>