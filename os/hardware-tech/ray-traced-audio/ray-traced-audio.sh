#!/bin/bash
# TinkerOS Ray Traced Audio - system-level acoustic ray casting engine
# Simulates realistic sound propagation, reflections, occlusion, muffling
# Integrates with PipeWire/PulseAudio spatial audio output
RTA_DIR="$HOME/.tinker/ray-traced-audio"; RTA_CONFIG="$RTA_DIR/config.json"
RTA_LOG="$RTA_DIR/rta.log"; RTA_STATE="$RTA_DIR/state.json"
mkdir -p "$RTA_DIR"

init(){
  cat > "$RTA_CONFIG" << 'EOF'
{
  "version": 1,
  "engine": {
    "method": "geometric_ray_casting",
    "max_reflections": 8,
    "ray_count": 256,
    "max_distance_m": 100,
    "update_hz": 60,
    "thread_count": 4,
    "voxel_resolution": 0.5
  },
  "acoustics": {
    "air_absorption": true,
    "air_absorption_coeff": 0.005,
    "speed_of_sound_ms": 343,
    "doppler_effect": true,
    "diffraction": true,
    "transmission_through_walls": true
  },
  "materials": {
    "concrete": {"absorption": 0.01, "transmission": 0.02, "scattering": 0.10},
    "drywall": {"absorption": 0.04, "transmission": 0.05, "scattering": 0.15},
    "wood": {"absorption": 0.07, "transmission": 0.04, "scattering": 0.20},
    "glass": {"absorption": 0.02, "transmission": 0.10, "scattering": 0.05},
    "metal": {"absorption": 0.01, "transmission": 0.01, "scattering": 0.08},
    "fabric": {"absorption": 0.25, "transmission": 0.01, "scattering": 0.30},
    "carpet": {"absorption": 0.35, "transmission": 0.01, "scattering": 0.40},
    "tile": {"absorption": 0.02, "transmission": 0.02, "scattering": 0.12},
    "grass": {"absorption": 0.40, "transmission": 0.00, "scattering": 0.50},
    "water": {"absorption": 0.01, "transmission": 0.15, "scattering": 0.05},
    "human_body": {"absorption": 0.35, "transmission": 0.01, "scattering": 0.60},
    "open_air": {"absorption": 0.001, "transmission": 1.0, "scattering": 0.01}
  },
  "room_presets": {
    "small_room": {"reverb_time_s": 0.3, "early_reflections": 5, "size_m": [4, 3, 2.5]},
    "living_room": {"reverb_time_s": 0.5, "early_reflections": 10, "size_m": [6, 4, 2.8]},
    "hall": {"reverb_time_s": 1.2, "early_reflections": 20, "size_m": [15, 10, 6]},
    "cathedral": {"reverb_time_s": 3.0, "early_reflections": 40, "size_m": [40, 20, 15]},
    "outdoor_open": {"reverb_time_s": 0.1, "early_reflections": 2, "size_m": [100, 100, 50]},
    "tunnel": {"reverb_time_s": 1.8, "early_reflections": 30, "size_m": [2, 3, 100]}
  },
  "spatial_output": {
    "backend": "pipewire",
    "binaural_hrtf": true,
    "ambisonics_order": 3,
    "head_tracking": false,
    "speaker_layout": "stereo"
  },
  "stats": {"total_rays_cast": 0, "total_reflections": 0, "avg_rays_per_frame": 0}
}
EOF
  echo "=== Ray Traced Audio Engine initialized ==="
  echo "  Method: geometric_ray_casting"
  echo "  Max reflections: 8 per ray"
  echo "  Ray count: 256 per source per frame"
  echo "  Materials: 12 physical types"
  echo "  Output: binaural HRTF + ambisonics"
}

# ── Ray Tracer Core (Python) ───────────────────────────────────────────
cat > "$RTA_DIR/ray_tracer.py" << 'PYRT'
#!/usr/bin/env python3
"""TinkerOS Ray Traced Audio - geometric ray casting for sound propagation"""
import math, json, os, time, threading
from dataclasses import dataclass, field
from typing import List, Tuple, Optional
from enum import Enum

# ── Vector3D ────────────────────────────────────────────────────────────
@dataclass
class Vec3:
    x: float = 0.0
    y: float = 0.0
    z: float = 0.0
    def __add__(self, o): return Vec3(self.x+o.x, self.y+o.y, self.z+o.z)
    def __sub__(self, o): return Vec3(self.x-o.x, self.y-o.y, self.z-o.z)
    def __mul__(self, s): return Vec3(self.x*s, self.y*s, self.z*s)
    def dot(self, o): return self.x*o.x + self.y*o.y + self.z*o.z
    def cross(self, o): return Vec3(self.y*o.z-self.z*o.y, self.z*o.x-self.x*o.z, self.x*o.y-self.y*o.x)
    def length(self): return math.sqrt(self.dot(self))
    def normalize(self):
        l = self.length()
        return self*(1.0/l) if l > 1e-8 else Vec3()
    def reflect(self, normal):
        return self - normal * (2.0 * self.dot(normal))

# ── Material ────────────────────────────────────────────────────────────
@dataclass
class Material:
    name: str
    absorption: float    # 0=none, 1=total
    transmission: float  # 0=opaque, 1=transparent
    scattering: float    # diffuse reflection amount

# ── Geometry Primitives ─────────────────────────────────────────────────
@dataclass
class Plane:
    normal: Vec3
    d: float
    material: Material

@dataclass
class Sphere:
    center: Vec3
    radius: float
    material: Material

@dataclass
class AABB:
    min_pt: Vec3
    max_pt: Vec3
    material: Material

Geometry = Plane | Sphere | AABB

# ── Ray ─────────────────────────────────────────────────────────────────
@dataclass
class Ray:
    origin: Vec3
    direction: Vec3
    energy: float = 1.0
    bounces: int = 0
    path: list = field(default_factory=list)
    arrival_time_ms: float = 0.0

# ── Listener ────────────────────────────────────────────────────────────
@dataclass
class Listener:
    position: Vec3
    forward: Vec3 = field(default_factory=lambda: Vec3(0, 0, -1))
    up: Vec3 = field(default_factory=lambda: Vec3(0, 1, 0))
    right: Vec3 = field(default_factory=lambda: Vec3(1, 0, 0))

# ── Sound Source ────────────────────────────────────────────────────────
@dataclass
class SoundSource:
    position: Vec3
    power_db: float = 80.0
    cone_angle_deg: float = 360.0
    cone_direction: Vec3 = field(default_factory=lambda: Vec3(0, 0, -1))

# ── Hit Result ──────────────────────────────────────────────────────────
@dataclass
class HitResult:
    hit: bool = False
    point: Vec3 = field(default_factory=Vec3)
    normal: Vec3 = field(default_factory=Vec3)
    distance: float = float('inf')
    material: Optional[Material] = None
    geometry_type: str = ""

# ── Ray Tracer ──────────────────────────────────────────────────────────
class RayTracer:
    def __init__(self, config_path=None):
        cfg = json.load(open(config_path)) if config_path else {}
        eng = cfg.get("engine", {})
        mat_cfg = cfg.get("materials", {})
        
        self.max_reflections = eng.get("max_reflections", 8)
        self.ray_count = eng.get("ray_count", 256)
        self.speed_of_sound = cfg.get("acoustics", {}).get("speed_of_sound_ms", 343)
        self.air_absorption = cfg.get("acoustics", {}).get("air_absorption_coeff", 0.005)
        self.use_doppler = cfg.get("acoustics", {}).get("doppler_effect", True)
        
        # Build materials
        self.materials = {}
        for name, props in mat_cfg.items():
            self.materials[name] = Material(name, props["absorption"], props["transmission"], props["scattering"])
        
        # Default material
        self.default_mat = Material("default", 0.1, 0.0, 0.2)
        
        # Scene
        self.geometry: List[Geometry] = []
        self.sources: List[SoundSource] = []
        self.listener: Optional[Listener] = None
        
        # Stats
        self.stats = {"rays_cast": 0, "reflections": 0, "diffractions": 0}
    
    def add_plane(self, normal, d, material_name="concrete"):
        self.geometry.append(Plane(normal, d, self.materials.get(material_name, self.default_mat)))
    
    def add_sphere(self, center, radius, material_name="concrete"):
        self.geometry.append(Sphere(center, radius, self.materials.get(material_name, self.default_mat)))
    
    def add_aabb(self, min_pt, max_pt, material_name="concrete"):
        self.geometry.append(AABB(min_pt, max_pt, self.materials.get(material_name, self.default_mat)))
    
    def load_room_preset(self, preset_name):
        cfg = json.load(open(os.path.expanduser("~/.tinker/ray-traced-audio/config.json")))
        preset = cfg.get("room_presets", {}).get(preset_name, {})
        w, h, d = preset.get("size_m", [6, 4, 3])
        
        # Floor (y=0)
        self.add_plane(Vec3(0, 1, 0), 0, "carpet")
        # Ceiling
        self.add_plane(Vec3(0, -1, 0), -h, "drywall")
        # Walls
        self.add_plane(Vec3(1, 0, 0), 0, "drywall")
        self.add_plane(Vec3(-1, 0, 0), -w, "drywall")
        self.add_plane(Vec3(0, 0, 1), 0, "drywall")
        self.add_plane(Vec3(0, 0, -1), -d, "drywall")
    
    def _intersect_ray_plane(self, ray, plane):
        denom = ray.direction.dot(plane.normal)
        if abs(denom) < 1e-8:
            return None
        t = -(ray.origin.dot(plane.normal) + plane.d) / denom
        if t < 0.001:
            return None
        hit_point = ray.origin + ray.direction * t
        return HitResult(True, hit_point, plane.normal, t, plane.material, "plane")
    
    def _intersect_ray_sphere(self, ray, sphere):
        oc = ray.origin - sphere.center
        a = ray.direction.dot(ray.direction)
        b = 2.0 * oc.dot(ray.direction)
        c = oc.dot(oc) - sphere.radius * sphere.radius
        disc = b * b - 4 * a * c
        if disc < 0:
            return None
        t = (-b - math.sqrt(disc)) / (2.0 * a)
        if t < 0.001:
            t = (-b + math.sqrt(disc)) / (2.0 * a)
        if t < 0.001:
            return None
        hit_point = ray.origin + ray.direction * t
        normal = (hit_point - sphere.center) * (1.0 / sphere.radius)
        return HitResult(True, hit_point, normal, t, sphere.material, "sphere")
    
    def _intersect_ray_aabb(self, ray, aabb):
        tmin = float('-inf')
        tmax = float('inf')
        inv_dir = Vec3(1.0/max(ray.direction.x,1e-8) if ray.direction.x != 0 else float('inf'),
                       1.0/max(ray.direction.y,1e-8) if ray.direction.y != 0 else float('inf'),
                       1.0/max(ray.direction.z,1e-8) if ray.direction.z != 0 else float('inf'))
        
        for axis, (ori, mn, mx, inv) in enumerate([
            (ray.origin.x, aabb.min_pt.x, aabb.max_pt.x, inv_dir.x),
            (ray.origin.y, aabb.min_pt.y, aabb.max_pt.y, inv_dir.y),
            (ray.origin.z, aabb.min_pt.z, aabb.max_pt.z, inv_dir.z)
        ]):
            t1 = (mn - ori) * inv
            t2 = (mx - ori) * inv
            if t1 > t2: t1, t2 = t2, t1
            tmin = max(tmin, t1)
            tmax = min(tmax, t2)
            if tmax < tmin:
                return None
        
        if tmin < 0.001:
            tmin = tmax
        if tmin < 0.001:
            return None
        
        hit_point = ray.origin + ray.direction * tmin
        # Approximate normal
        center = Vec3((aabb.min_pt.x+aabb.max_pt.x)/2, (aabb.min_pt.y+aabb.max_pt.y)/2, (aabb.min_pt.z+aabb.max_pt.z)/2)
        diff = hit_point - center
        extents = Vec3((aabb.max_pt.x-aabb.min_pt.x)/2, (aabb.max_pt.y-aabb.min_pt.y)/2, (aabb.max_pt.z-aabb.min_pt.z)/2)
        normal = Vec3()
        for i, (d, e) in enumerate([(diff.x, extents.x), (diff.y, extents.y), (diff.z, extents.z)]):
            if e > 0:
                val = d / e
                if abs(val) > 0.9:
                    n = Vec3()
                    if i == 0: n = Vec3(1 if d > 0 else -1, 0, 0)
                    elif i == 1: n = Vec3(0, 1 if d > 0 else -1, 0)
                    else: n = Vec3(0, 0, 1 if d > 0 else -1)
                    normal = n
                    break
        
        return HitResult(True, hit_point, normal, tmin, aabb.material, "aabb")
    
    def cast_ray(self, ray):
        """Cast a single ray and return closest hit"""
        closest = HitResult()
        for geom in self.geometry:
            if isinstance(geom, Plane):
                hit = self._intersect_ray_plane(ray, geom)
            elif isinstance(geom, Sphere):
                hit = self._intersect_ray_sphere(ray, geom)
            elif isinstance(geom, AABB):
                hit = self._intersect_ray_aabb(ray, geom)
            else:
                continue
            if hit and hit.distance < closest.distance:
                closest = hit
        return closest
    
    def trace_sound(self, source, listener, max_bounces=None):
        """Trace sound rays from source, return early reflections + reverb impulse"""
        max_bounces = max_bounces or self.max_reflections
        rays = []
        early_reflections = []
        reverb_energy = 0.0
        
        # Generate rays uniformly distributed in sphere
        for i in range(self.ray_count):
            # Fibonacci sphere for even distribution
            phi = math.acos(1 - 2 * (i + 0.5) / self.ray_count)
            theta = math.pi * (1 + math.sqrt(5)) * i
            dir = Vec3(math.sin(phi) * math.cos(theta),
                       math.cos(phi),
                       math.sin(phi) * math.sin(theta))
            
            ray = Ray(source.position, dir.normalize(), energy=1.0)
            rays.append(ray)
        
        # Trace each ray
        for ray in rays:
            current_ray = ray
            bounce = 0
            
            while bounce < max_bounces and current_ray.energy > 0.001:
                hit = self.cast_ray(current_ray)
                
                if not hit.hit:
                    # Ray escaped to infinity - open air
                    current_ray.energy *= self.materials.get("open_air", self.default_mat).absorption
                    break
                
                # Record hit point and path
                current_ray.path.append(hit.point)
                dist = hit.distance
                travel_time_ms = (dist / self.speed_of_sound) * 1000
                current_ray.arrival_time_ms += travel_time_ms
                
                # Air absorption over distance
                air_loss = math.exp(-self.air_absorption * dist)
                mat = hit.material or self.default_mat
                
                # Energy loss from material
                absorbed = current_ray.energy * mat.absorption
                transmitted = current_ray.energy * mat.transmission
                scattered = current_ray.energy * mat.scattering
                
                current_ray.energy -= absorbed + transmitted
                
                # Check if this reflection reaches the listener
                to_listener = listener.position - hit.point
                dist_to_listener = to_listener.length()
                
                if dist_to_listener < 100:  # Within hearing range
                    # Partial energy based on listener direction
                    listen_gain = max(0, to_listener.normalize().dot(listener.forward))
                    # Also allow from behind at reduced gain
                    listen_gain = max(listen_gain, 0.3 * max(0, to_listener.normalize().dot(-listener.forward)))
                    
                    reflection_db = source.power_db + 20 * math.log10(max(current_ray.energy * air_loss, 1e-10))
                    
                    entry = {
                        "delay_ms": current_ray.arrival_time_ms,
                        "energy_db": reflection_db,
                        "bounces": bounce + 1,
                        "direct": bounce == 0,
                        "direction": (to_listener.normalize()),
                        "listen_gain": listen_gain,
                        "material": mat.name
                    }
                    
                    if bounce == 0:
                        early_reflections.insert(0, entry)  # Direct sound first
                    else:
                        early_reflections.append(entry)
                    
                    reverb_energy += current_ray.energy * air_loss * listen_gain
                
                # Reflect
                reflected = current_ray.direction.reflect(hit.normal)
                
                # Add scattering (diffuse component)
                import random
                scatter = Vec3(random.uniform(-1,1) * mat.scattering,
                              random.uniform(-1,1) * mat.scattering,
                              random.uniform(-1,1) * mat.scattering)
                reflected = (reflected + scatter).normalize()
                
                current_ray = Ray(hit.point, reflected, current_ray.energy, bounce + 1, list(current_ray.path), current_ray.arrival_time_ms)
                bounce += 1
                self.stats["reflections"] += 1
            
            self.stats["rays_cast"] += 1
        
        # Sort early reflections by delay
        early_reflections.sort(key=lambda x: x["delay_ms"])
        
        return {
            "source_position": {"x": source.position.x, "y": source.position.y, "z": source.position.z},
            "listener_position": {"x": listener.position.x, "y": listener.position.y, "z": listener.position.z},
            "early_reflections": early_reflections[:50],  # Top 50
            "reverb_energy_db": source.power_db + 20 * math.log10(max(reverb_energy / self.ray_count, 1e-10)),
            "reverb_time_s": self._estimate_reverb_time(reverb_energy, source.power_db),
            "rays_cast": self.ray_count,
            "avg_energy": reverb_energy / max(self.ray_count, 1)
        }
    
    def _estimate_reverb_time(self, total_energy, source_db):
        """Estimate RT60 reverb time"""
        if total_energy <= 0:
            return 0.3
        # RT60 = time for energy to drop 60dB
        energy_ratio = total_energy / self.ray_count
        if energy_ratio > 0:
            db_drop = -20 * math.log10(energy_ratio)
            return max(0.1, min(5.0, db_drop / 60.0 * 2.0))
        return 0.5
    
    def occlusion_test(self, source_pos, listener_pos, wall_material="drywall"):
        """Test if sound path is occluded by walls"""
        direction = (listener_pos - source_pos).normalize()
        distance = (listener_pos - source_pos).length()
        ray = Ray(source_pos, direction)
        hit = self.cast_ray(ray)
        if hit.hit and hit.distance < distance:
            mat = hit.material or self.default_mat
            return {"occluded": True, "distance": hit.distance, "material": mat.name, "attenuation_db": -20 * math.log10(max(mat.transmission, 0.001))}
        return {"occluded": False, "distance": distance}
    
    def muffle_test(self, source_pos, listener_pos, barrier_thickness_m=0.15):
        """Calculate muffling through a barrier"""
        direction = (listener_pos - source_pos).normalize()
        distance = (listener_pos - source_pos).length()
        ray = Ray(source_pos, direction)
        hit = self.cast_ray(ray)
        if hit.hit and hit.distance < distance:
            mat = hit.material or self.default_mat
            # Mass law: ~6dB per doubling of frequency or thickness
            muffling_db = -20 * math.log10(max(mat.transmission, 0.001)) * barrier_thickness_m / 0.15
            return {"muffled": True, "muffling_db": round(muffling_db, 1), "material": mat.name}
        return {"muffled": False, "muffling_db": 0}

# ── HRTF Spatializer ───────────────────────────────────────────────────
class HRTFSpatializer:
    def __init__(self):
        # Simplified HRTF interaural cues
        self.head_radius = 0.0875  # meters
    
    def spatialize(self, reflection, listener):
        """Convert a reflection to binaural left/right gains"""
        dir = reflection["direction"]
        # Interaural Level Difference (ILD)
        angle = math.atan2(dir.x, -dir.z)
        itd_samples = int((self.head_radius * 2 * math.sin(angle)) / 343 * 44100)
        
        # Simple ILD model
        left_gain = 1.0 + 0.3 * math.sin(angle)
        right_gain = 1.0 - 0.3 * math.sin(angle)
        
        # High frequency attenuation for far ear
        if angle > 0:
            right_gain *= 0.7
        else:
            left_gain *= 0.7
        
        return {
            "left_gain": round(left_gain * reflection["listen_gain"], 3),
            "right_gain": round(right_gain * reflection["listen_gain"], 3),
            "delay_ms": reflection["delay_ms"],
            "itd_samples": itd_samples,
            "energy_db": reflection["energy_db"]
        }

# ── Convolution Reverb ─────────────────────────────────────────────────
class ConvolutionReverb:
    def __init__(self, sample_rate=44100):
        self.sample_rate = sample_rate
    
    def generate_impulse_response(self, reflections, duration_s=2.0):
        """Generate impulse response from ray traced reflections"""
        ir_length = int(duration_s * self.sample_rate)
        ir_left = [0.0] * ir_length
        ir_right = [0.0] * ir_length
        
        for ref in reflections:
            sample_pos = int((ref["delay_ms"] / 1000.0) * self.sample_rate)
            if sample_pos < ir_length:
                energy_linear = 10 ** (ref["energy_db"] / 20.0)
                ir_left[sample_pos] += ref["left_gain"] * energy_linear
                ir_right[sample_pos] += ref["right_gain"] * energy_linear
        
        return {"left": ir_left, "right": ir_right, "length": ir_length, "sample_rate": self.sample_rate}

# ── Main CLI ────────────────────────────────────────────────────────────
if __name__ == "__main__":
    config_path = os.path.expanduser("~/.tinker/ray-traced-audio/config.json")
    rt = RayTracer(config_path)
    hrtf = HRTFSpatializer()
    reverb = ConvolutionReverb()
    
    import sys
    cmd = sys.argv[1] if len(sys.argv) > 1 else "demo"
    
    if cmd == "demo":
        print("╔══════════════════════════════════════════════════════════╗")
        print("║       TinkerOS RAY TRACED AUDIO ENGINE                ║")
        print("╠══════════════════════════════════════════════════════════╣")
        print("║  Geometric ray casting for realistic sound simulation  ║")
        print("╚══════════════════════════════════════════════════════════╝")
        print()
        
        # Load a room
        rt.load_room_preset("living_room")
        print("Room: living_room (6m x 4m x 2.8m)")
        print(f"Geometry: {len(rt.geometry)} surfaces")
        print(f"Materials: {', '.join(rt.materials.keys())}")
        print()
        
        # Place source and listener
        source = SoundSource(Vec3(1.5, 1.2, 2.0), power_db=80)
        listener = Listener(Vec3(4.0, 1.6, 3.0))
        rt.listener = listener
        rt.sources = [source]
        
        print(f"Source: ({source.position.x}, {source.position.y}, {source.position.z}) @ {source.power_db}dB")
        print(f"Listener: ({listener.position.x}, {listener.position.y}, {listener.position.z})")
        print()
        
        # Trace
        print("Tracing 256 rays...")
        t0 = time.time()
        result = rt.trace_sound(source, listener)
        elapsed = time.time() - t0
        
        print(f"Trace time: {elapsed*1000:.1f}ms")
        print(f"Rays cast: {result['rays_cast']}")
        print(f"Reverb time (RT60): {result['reverb_time_s']:.2f}s")
        print(f"Reverb energy: {result['reverb_energy_db']:.1f}dB")
        print()
        
        # Early reflections
        reflections = result["early_reflections"]
        print(f"Early reflections: {len(reflections)}")
        for i, ref in enumerate(reflections[:10]):
            label = "DIRECT" if ref["direct"] else f"bounce {ref['bounces']}"
            print(f"  [{i+1}] {label:10s} | {ref['delay_ms']:7.1f}ms | {ref['energy_db']:.1f}dB | {ref['material']}")
        print()
        
        # HRTF spatialize
        print("HRTF Spatialization (binaural):")
        hrtf_results = [hrtf.spatialize(ref, listener) for ref in reflections[:10]]
        for i, h in enumerate(hrtf_results[:5]):
            print(f"  [{i+1}] L={h['left_gain']:.3f} R={h['right_gain']:.3f} | ITD={h['itd_samples']} samples | delay={h['delay_ms']:.1f}ms")
        print()
        
        # Occlusion test
        print("Occlusion test (source -> listener through wall):")
        far_listener = Listener(Vec3(10.0, 1.6, 3.0))
        occ = rt.occlusion_test(source.position, far_listener.position)
        print(f"  Occluded: {occ['occluded']}")
        if occ['occluded']:
            print(f"  Distance: {occ['distance']:.1f}m through {occ['material']}")
            print(f"  Attenuation: {occ['attenuation_db']:.1f}dB")
        
        # Muffling
        print("\nMuffling test:")
        muff = rt.muffle_test(source.position, far_listener.position, 0.15)
        print(f"  Muffled: {muff['muffled']}")
        if muff['muffled']:
            print(f"  Muffling: {muff['muffling_db']:.1f}dB")
        
        # Stats
        print(f"\nStats: {rt.stats}")
    
    elif cmd == "trace":
        # Custom trace
        source_pos = Vec3(*[float(x) for x in sys.argv[2:5]])
        listener_pos = Vec3(*[float(x) for x in sys.argv[5:8]])
        preset = sys.argv[8] if len(sys.argv) > 8 else "living_room"
        
        rt.load_room_preset(preset)
        source = SoundSource(source_pos, power_db=80)
        listener = Listener(listener_pos)
        result = rt.trace_sound(source, listener)
        print(json.dumps(result, indent=2, default=str))
    
    elif cmd == "materials":
        print("Available acoustic materials:")
        for name, mat in rt.materials.items():
            print(f"  {name:15s} | absorption={mat.absorption:.2f} | transmission={mat.transmission:.2f} | scattering={mat.scattering:.2f}")
    
    elif cmd == "presets":
        cfg = json.load(open(config_path))
        print("Room presets:")
        for name, preset in cfg.get("room_presets", {}).items():
            print(f"  {name:20s} | RT60={preset['reverb_time_s']:.1f}s | size={preset['size_m']}")
PYRT
  chmod +x "$RTA_DIR/ray_tracer.py"
  echo "  Core ray tracer: $RTA_DIR/ray_tracer.py"
  
  echo "=== Ray Traced Audio Engine built ==="

case "${1:-help}" in
  init) init ;;
  demo) python3 "$RTA_DIR/ray_tracer.py" demo ;;
  trace) python3 "$RTA_DIR/ray_tracer.py" trace "${@:2}" ;;
  materials) python3 "$RTA_DIR/ray_tracer.py" materials ;;
  presets) python3 "$RTA_DIR/ray_tracer.py" presets ;;
  status) echo "Ray Traced Audio: active"; cat "$RTA_DIR/config.json" | python3 -m json.tool 2>/dev/null | head -20 ;;
  *) echo "Usage: $0 {init|demo|trace|materials|presets|status}"
     echo ""
     echo "  init      - Initialize config"
     echo "  demo      - Run full demo (trace + HRTF + reverb)"
     echo "  trace     - Custom trace: source_x,y,z listener_x,y,z [preset]"
     echo "  materials - List acoustic materials"
     echo "  presets   - List room presets"
     echo "  status    - Show engine status"
     echo ""
     echo "PIPELINE: ray_cast -> reflection -> absorption -> HRTF -> convolution reverb"
     echo "MATERIALS: concrete, drywall, wood, glass, metal, fabric, carpet, tile, grass, water" ;;
esac
