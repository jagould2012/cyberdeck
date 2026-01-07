# Gallery

<div id="gallery">
	<template v-for="(data, prefix) in galleryImages" :key="prefix">
		<section v-if="data && data.files && data.files.length">
			<h3>{{ data.title }}</h3>
			<div class="gallery-grid">
				<img 
					v-for="src in data.files" 
					:key="src" 
					:src="src" 
					class="gallery-item"
					loading="lazy"
				/>
			</div>
		</section>
	</template>
	<p v-if="loading">Loading gallery...</p>
</div>